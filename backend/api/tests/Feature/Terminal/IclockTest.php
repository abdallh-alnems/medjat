<?php

declare(strict_types=1);

namespace Tests\Feature\Terminal;

use App\Modules\Notifications\Domain\PushSender;
use App\Shared\Time\TenantClock;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\CreatesFixtures;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * The ZKTeco terminal endpoint.
 *
 * Most of these assert the same thing from different angles: that whatever
 * happens, the device gets a 200 with plain text. Anything else makes it
 * re-send the same batch forever while recording nothing new.
 */
final class IclockTest extends TestCase
{
    use CreatesFixtures;
    use DatabaseTransactions;

    private const SERIAL = 'ZK1234567890';

    private int $tenantId;

    private int $branchId;

    private int $employeeId;

    private int $deviceId;

    protected function setUp(): void
    {
        parent::setUp();

        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = $this->createTenant();
        DB::table('tenants')->where('id', $this->tenantId)->update(['timezone' => 'Africa/Cairo']);

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId, 'name' => 'Terminal branch', 'is_active' => 1,
        ]);

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'name' => 'Terminal user',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
        ]);

        DB::table('attendance_devices')->where('serial_number', self::SERIAL)->delete();

        $this->deviceId = (int) DB::table('attendance_devices')->insertGetId([
            'serial_number' => self::SERIAL,
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'name' => 'Front door',
            'status' => 'active',
            'clock_offset_minutes' => 0,
        ]);

        DB::table('device_users')->insert([
            'tenant_id' => $this->tenantId,
            'device_id' => $this->deviceId,
            'device_user_id' => '7',
            'employee_id' => $this->employeeId,
        ]);
    }

    /**
     * @return TestResponse<\Illuminate\Http\Response>
     */
    private function upload(string $table, string $body, string $serial = self::SERIAL): TestResponse
    {
        return $this->call(
            'POST',
            '/iclock/cdata?SN='.$serial.'&table='.$table,
            [], [], [], ['CONTENT_TYPE' => 'text/plain'], $body,
        );
    }

    /**
     * @return TestResponse<\Illuminate\Http\Response>
     */
    private function poll(string $action, string $query): TestResponse
    {
        return $this->call('GET', '/iclock/'.$action.'?'.$query);
    }

    private static function punchLine(string $pin, string $at, int $status = 0, int $verify = 1): string
    {
        return implode("\t", [$pin, $at, (string) $status, (string) $verify]);
    }

    /**
     * A timestamp inside the ingestor's sanity window.
     *
     * Dates are relative because the ingestor rejects anything more than a
     * couple of months old as a misconfigured device clock — which is the point
     * of that guard, and a fixed date in a test would quietly stop exercising
     * this path as the suite ages.
     */
    private function recently(string $time): string
    {
        return TenantClock::now($this->tenantId)->modify('-1 day')->format('Y-m-d').' '.$time;
    }

    private function recentDate(): string
    {
        return TenantClock::now($this->tenantId)->modify('-1 day')->format('Y-m-d');
    }

    public function test_the_handshake_answers_with_the_options_the_firmware_expects(): void
    {
        $response = $this->poll('cdata', 'SN='.self::SERIAL.'&DeviceType=uFace800&pushver=2.4.1')
            ->assertOk()
            ->assertHeader('Content-Type', 'text/plain; charset=utf-8');

        $body = $response->getContent();
        $this->assertIsString($body);
        $this->assertStringContainsString('GET OPTION FROM: '.self::SERIAL, $body);
        // Cairo is UTC+2 or +3 depending on the season; either is right, an
        // absent TimeZone line is not.
        $this->assertMatchesRegularExpression('/TimeZone=[23]/', $body);
        $this->assertStringContainsString("\r\n", $body);

        // Whatever it volunteered about itself is kept.
        $this->assertDatabaseHas('attendance_devices', [
            'id' => $this->deviceId, 'model' => 'uFace800', 'firmware' => '2.4.1',
        ]);
    }

    public function test_a_handshake_that_omits_a_field_does_not_erase_what_we_knew(): void
    {
        $this->poll('cdata', 'SN='.self::SERIAL.'&DeviceType=uFace800&pushver=2.4.1')->assertOk();
        $this->poll('cdata', 'SN='.self::SERIAL)->assertOk();

        $this->assertDatabaseHas('attendance_devices', [
            'id' => $this->deviceId, 'model' => 'uFace800', 'firmware' => '2.4.1',
        ]);
    }

    public function test_a_punch_upload_is_stored_and_acknowledged_with_its_count(): void
    {
        $body = self::punchLine('7', $this->recently('08:55:00'))."\n".self::punchLine('7', $this->recently('17:05:00'));

        $this->upload('ATTLOG', $body)->assertOk()->assertSee('OK: 2', false);

        $this->assertSame(2, DB::table('device_punches')
            ->where('device_id', $this->deviceId)->count());
    }

    public function test_a_punch_reaches_the_employee_it_is_mapped_to(): void
    {
        $this->upload('ATTLOG', self::punchLine('7', $this->recently('08:55:00')))->assertOk();

        $this->assertDatabaseHas('attendance', [
            'employee_id' => $this->employeeId,
            'date' => $this->recentDate(),
            'check_in_time' => '08:55:00',
        ]);
    }

    public function test_a_re_sent_batch_is_acknowledged_without_being_stored_twice(): void
    {
        // The device re-sends whenever it is unsure we heard, so it must be
        // told yes without producing a second punch.
        $line = self::punchLine('7', $this->recently('08:55:00'));

        $this->upload('ATTLOG', $line)->assertOk()->assertSee('OK: 1', false);
        $this->upload('ATTLOG', $line)->assertOk()->assertSee('OK: 1', false);

        $this->assertSame(1, DB::table('device_punches')->where('device_id', $this->deviceId)->count());
    }

    public function test_space_separated_firmware_is_read_too(): void
    {
        // Tabs are the spec; some builds emit runs of spaces.
        $this->upload('ATTLOG', '7    '.$this->recently('08:55:00').'    0    1')
            ->assertOk()
            ->assertSee('OK: 1', false);
    }

    public function test_a_clock_offset_corrects_a_misconfigured_terminal(): void
    {
        DB::table('attendance_devices')->where('id', $this->deviceId)
            ->update(['clock_offset_minutes' => -60]);

        $this->upload('ATTLOG', self::punchLine('7', $this->recently('09:55:00')))->assertOk();

        $this->assertDatabaseHas('device_punches', [
            'device_id' => $this->deviceId, 'punched_at' => $this->recently('08:55:00'),
        ]);
    }

    public function test_a_malformed_line_is_skipped_without_failing_the_batch(): void
    {
        $body = "garbage\n".self::punchLine('7', $this->recently('08:55:00'))."\n\n";

        $this->upload('ATTLOG', $body)->assertOk()->assertSee('OK: 1', false);
    }

    public function test_an_unknown_serial_gets_a_row_and_nothing_else(): void
    {
        DB::table('attendance_devices')->where('serial_number', 'ZKNEVERSEEN1')->delete();

        $this->upload('ATTLOG', self::punchLine('9', $this->recently('08:00:00')), 'ZKNEVERSEEN1')->assertOk();

        // How a device appears in the unclaimed list for somebody to attach.
        $this->assertDatabaseHas('attendance_devices', [
            'serial_number' => 'ZKNEVERSEEN1', 'status' => 'unclaimed', 'tenant_id' => null,
        ]);
    }

    public function test_a_punch_from_an_unclaimed_device_is_kept_for_replay(): void
    {
        DB::table('attendance_devices')->where('id', $this->deviceId)
            ->update(['tenant_id' => null, 'status' => 'unclaimed']);

        $this->upload('ATTLOG', self::punchLine('7', $this->recently('08:55:00')))->assertOk();

        $this->assertDatabaseHas('device_punches', [
            'device_id' => $this->deviceId, 'state' => 'unmatched',
        ]);
    }

    public function test_a_request_with_no_serial_is_answered_politely(): void
    {
        // So it stops retrying rather than spinning.
        $this->poll('cdata', '')->assertOk()->assertSee('OK', false);
    }

    public function test_a_disabled_device_is_acknowledged_and_ignored(): void
    {
        DB::table('attendance_devices')->where('id', $this->deviceId)->update(['status' => 'disabled']);

        // It keeps its own log and delivers it when re-enabled.
        $this->upload('ATTLOG', self::punchLine('7', $this->recently('08:55:00')))->assertOk()->assertSee('OK', false);

        $this->assertSame(0, DB::table('device_punches')->where('device_id', $this->deviceId)->count());
    }

    public function test_contact_is_recorded_even_when_nothing_else_happens(): void
    {
        $this->poll('ping', 'SN='.self::SERIAL)->assertOk();

        $this->assertNotNull(DB::table('attendance_devices')->where('id', $this->deviceId)->value('last_seen_at'));
    }

    public function test_a_user_upload_registers_the_terminals_own_users(): void
    {
        $this->upload('OPERLOG', "USER PIN=12\tName=Sara\tPri=0\tCard=8899")->assertOk()->assertSee('OK', false);

        $this->assertDatabaseHas('device_users', [
            'device_id' => $this->deviceId, 'device_user_id' => '12', 'device_name' => 'Sara',
        ]);
    }

    public function test_biometric_templates_are_acknowledged_and_not_stored(): void
    {
        // Megabytes of base64 belonging to the device, which does its own
        // matching — keeping them would be retaining an irrevocable biometric
        // for no purpose.
        $before = DB::table('device_users')->where('device_id', $this->deviceId)->count();

        $this->upload('OPERLOG', 'FP PIN=12 FID=0 TMP='.str_repeat('A', 512))
            ->assertOk()
            ->assertSee('OK', false);

        $this->assertSame($before, DB::table('device_users')->where('device_id', $this->deviceId)->count());
    }

    public function test_a_self_description_upload_is_recorded(): void
    {
        $this->upload('OPTIONS', "DeviceName=uFace302\tFWVersion=Ver 6.60\tUserCount=48")->assertOk();

        $this->assertDatabaseHas('attendance_devices', [
            'id' => $this->deviceId, 'model' => 'uFace302', 'firmware' => 'Ver 6.60', 'user_count' => 48,
        ]);
    }

    public function test_a_command_poll_hands_over_queued_work_and_marks_it_sent(): void
    {
        $commandId = (int) DB::table('device_commands')->insertGetId([
            'tenant_id' => $this->tenantId,
            'device_id' => $this->deviceId,
            'kind' => 'reboot',
            'payload' => 'REBOOT',
            'state' => 'queued',
        ]);

        $this->poll('getrequest', 'SN='.self::SERIAL)
            ->assertOk()
            ->assertSee('C:'.$commandId.':REBOOT', false);

        $this->assertDatabaseHas('device_commands', ['id' => $commandId, 'state' => 'sent']);
    }

    public function test_a_poll_with_nothing_queued_answers_ok(): void
    {
        $this->poll('getrequest', 'SN='.self::SERIAL)->assertOk()->assertSee('OK', false);
    }

    public function test_a_stale_command_is_failed_rather_than_executed_late(): void
    {
        // A terminal back after a week should not suddenly apply what somebody
        // queued before the problem was solved another way.
        $commandId = (int) DB::table('device_commands')->insertGetId([
            'tenant_id' => $this->tenantId,
            'device_id' => $this->deviceId,
            'kind' => 'reboot',
            'payload' => 'REBOOT',
            'state' => 'queued',
            'created_at' => DB::raw('DATE_SUB(NOW(), INTERVAL 3 DAY)'),
        ]);

        $this->poll('getrequest', 'SN='.self::SERIAL)->assertOk()->assertSee('OK', false);

        $this->assertDatabaseHas('device_commands', [
            'id' => $commandId, 'state' => 'failed', 'result_code' => 'expired',
        ]);
    }

    public function test_an_unclaimed_device_is_never_given_commands(): void
    {
        DB::table('attendance_devices')->where('id', $this->deviceId)->update(['tenant_id' => null]);

        $this->poll('getrequest', 'SN='.self::SERIAL)->assertOk()->assertSee('OK', false);
    }

    public function test_a_command_result_closes_the_command(): void
    {
        $commandId = (int) DB::table('device_commands')->insertGetId([
            'tenant_id' => $this->tenantId,
            'device_id' => $this->deviceId,
            'kind' => 'reboot',
            'payload' => 'REBOOT',
            'state' => 'sent',
        ]);

        $this->call(
            'POST', '/iclock/devicecmd?SN='.self::SERIAL,
            [], [], [], ['CONTENT_TYPE' => 'text/plain'], "ID={$commandId}\tReturn=0\tCMD=REBOOT",
        )->assertOk();

        $this->assertDatabaseHas('device_commands', ['id' => $commandId, 'state' => 'done']);
    }

    public function test_a_non_zero_return_code_marks_the_command_failed(): void
    {
        $commandId = (int) DB::table('device_commands')->insertGetId([
            'tenant_id' => $this->tenantId,
            'device_id' => $this->deviceId,
            'kind' => 'reboot',
            'payload' => 'REBOOT',
            'state' => 'sent',
        ]);

        $this->call(
            'POST', '/iclock/devicecmd?SN='.self::SERIAL,
            [], [], [], ['CONTENT_TYPE' => 'text/plain'], "ID={$commandId}\tReturn=-14",
        )->assertOk();

        $this->assertDatabaseHas('device_commands', [
            'id' => $commandId, 'state' => 'failed', 'result_code' => '-14',
        ]);
    }

    public function test_an_unrecognised_action_is_acknowledged(): void
    {
        foreach (['ping', 'fdata', 'edata', 'querydata', 'somethingnew'] as $action) {
            $this->poll($action, 'SN='.self::SERIAL)->assertOk()->assertSee('OK', false);
        }
    }

    public function test_the_path_routed_form_works_as_well_as_the_filename(): void
    {
        // /iclock/<action> is what the firmware derives from its server
        // setting; the filename is what the old deployment used.
        $this->call('GET', '/iclock/getrequest?SN='.self::SERIAL)->assertOk()->assertSee('OK', false);
    }
}
