<?php

declare(strict_types=1);

namespace Tests\Feature\Devices;

use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Devices\Domain\AttendanceDevice;
use App\Modules\Notifications\Domain\PushSender;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Fingerprint terminals: claiming one, matching its User IDs to people, and
 * turning its punches into attendance.
 */
final class DeviceFleetTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $branchId;

    private int $employeeId;

    private string $adminToken;

    private string $attendanceToken;

    private string $viewerToken;

    protected function setUp(): void
    {
        parent::setUp();
        TenantClock::flush();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Device branch',
        ]);

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Terminal user',
            'status' => 'active',
            'base_salary' => 3000,
            'branch_id' => $this->branchId,
            'work_start_time' => '09:00:00',
            'work_end_time' => '17:00:00',
        ]);

        $this->adminToken = $this->admin($firebase, 'general_manager');
        $this->attendanceToken = $this->admin($firebase, 'attendance');
        $this->viewerToken = $this->admin($firebase, 'viewer');
    }

    private function admin(FakeFirebaseTokenVerifier $firebase, string $role): string
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        DB::table('admins')->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Admin '.$role,
            'role' => $role,
            'is_active' => 1,
        ]);

        return $firebase->issue($uid);
    }

    private function asAdmin(): self
    {
        $this->withHeader('X-Firebase-Token', $this->adminToken);

        return $this;
    }

    private function serial(): string
    {
        return 'ZK'.strtoupper(bin2hex(random_bytes(4)));
    }

    private function registered(?string $serial = null): int
    {
        $response = $this->asAdmin()->postJson('/v1/devices', [
            'serial_number' => $serial ?? $this->serial(),
            'branch_id' => $this->branchId,
            'name' => 'Front door',
        ])->assertOk();

        return Value::int($response->json('data.device.id'));
    }

    // ── Claiming ─────────────────────────────────────────────────────────

    public function test_a_terminal_is_claimed_by_its_serial(): void
    {
        $serial = $this->serial();
        $id = $this->registered($serial);

        $this->assertDatabaseHas('attendance_devices', [
            'id' => $id,
            'serial_number' => $serial,
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'status' => 'active',
        ]);
    }

    public function test_a_serial_is_stored_upper_cased(): void
    {
        // Compared upper-cased everywhere, so a lower-case entry must not
        // create a second row for the same physical device.
        $serial = $this->serial();

        $this->asAdmin()->postJson('/v1/devices', [
            'serial_number' => strtolower($serial),
            'branch_id' => $this->branchId,
        ])->assertOk();

        $this->assertDatabaseHas('attendance_devices', ['serial_number' => $serial]);
    }

    public function test_a_nonsense_serial_is_refused(): void
    {
        $this->asAdmin()->postJson('/v1/devices', [
            'serial_number' => 'no',
            'branch_id' => $this->branchId,
        ])->assertStatus(422)->assertJsonPath('error_code', 'INVALID_SERIAL');
    }

    public function test_a_device_owned_by_another_company_is_not_taken_over(): void
    {
        // Silently moving it would hand that company's punch stream to a
        // stranger.
        $otherTenant = Value::int(DB::table('tenants')->where('id', '!=', $this->tenantId)->value('id'));
        $serial = $this->serial();

        DB::table('attendance_devices')->insert([
            'tenant_id' => $otherTenant,
            'serial_number' => $serial,
            'status' => 'active',
        ]);

        $this->asAdmin()->postJson('/v1/devices', [
            'serial_number' => $serial,
            'branch_id' => $this->branchId,
        ])->assertStatus(409)->assertJsonPath('error_code', 'DEVICE_ALREADY_CLAIMED');
    }

    public function test_claiming_adopts_what_the_device_sent_before_it_was_claimed(): void
    {
        // Its user list and the punches from the day it was mounted belong to
        // the company that claims it.
        $serial = $this->serial();
        $deviceId = (int) DB::table('attendance_devices')->insertGetId([
            'serial_number' => $serial,
            'status' => 'unclaimed',
            'first_seen_at' => DB::raw('NOW()'),
            'last_seen_at' => DB::raw('NOW()'),
        ]);
        DB::table('device_users')->insert([
            'device_id' => $deviceId,
            'device_user_id' => '7',
        ]);
        DB::table('device_punches')->insert([
            'device_id' => $deviceId,
            'device_user_id' => '7',
            'punched_at' => TenantClock::timestamp($this->tenantId),
            'state' => 'unmatched',
        ]);

        $this->registered($serial);

        $this->assertDatabaseHas('device_users', ['device_id' => $deviceId, 'tenant_id' => $this->tenantId]);
        $this->assertDatabaseHas('device_punches', ['device_id' => $deviceId, 'tenant_id' => $this->tenantId]);
    }

    public function test_claiming_hardware_needs_the_settings_permission(): void
    {
        $this->withHeader('X-Firebase-Token', $this->attendanceToken)
            ->postJson('/v1/devices', [
                'serial_number' => $this->serial(),
                'branch_id' => $this->branchId,
            ])->assertForbidden();
    }

    // ── The fleet screen ─────────────────────────────────────────────────

    public function test_the_fleet_says_whether_a_terminal_is_alive(): void
    {
        $id = $this->registered();
        DB::table('attendance_devices')->where('id', $id)
            ->update(['last_seen_at' => DB::raw('DATE_SUB(NOW(), INTERVAL 10 SECOND)')]);

        $devices = $this->asAdmin()->getJson('/v1/devices')->assertOk()->json('data.devices');
        $this->assertIsArray($devices);

        $mine = null;
        foreach ($devices as $device) {
            if (is_array($device) && Value::int($device['id']) === $id) {
                $mine = $device;
            }
        }

        $this->assertIsArray($mine);
        $this->assertTrue($mine['is_online']);
    }

    public function test_a_terminal_silent_for_too_long_reads_as_dark(): void
    {
        $id = $this->registered();
        DB::table('attendance_devices')->where('id', $id)
            ->update(['last_seen_at' => DB::raw('DATE_SUB(NOW(), INTERVAL 1 HOUR)')]);

        $devices = $this->asAdmin()->getJson('/v1/devices')->assertOk()->json('data.devices');
        $this->assertIsArray($devices);

        foreach ($devices as $device) {
            if (is_array($device) && Value::int($device['id']) === $id) {
                $this->assertFalse($device['is_online']);
            }
        }
    }

    public function test_the_fleet_is_readable_by_whoever_runs_attendance(): void
    {
        // Reachable from two directions; either must not meet a 403 on a page
        // their own navigation offers them.
        $this->withHeader('X-Firebase-Token', $this->attendanceToken)
            ->getJson('/v1/devices')->assertOk();
    }

    public function test_the_fleet_is_closed_to_somebody_with_neither_permission(): void
    {
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->getJson('/v1/devices')->assertForbidden();
    }

    // ── Configuring and releasing ────────────────────────────────────────

    public function test_settings_are_changed(): void
    {
        $id = $this->registered();

        $this->asAdmin()->postJson('/v1/devices/update', [
            'device_id' => $id,
            'name' => 'Back door',
            'direction_mode' => 'device_status',
            'min_interval_seconds' => 120,
            'clock_offset_minutes' => -60,
        ])->assertOk();

        $this->assertDatabaseHas('attendance_devices', [
            'id' => $id,
            'name' => 'Back door',
            'direction_mode' => 'device_status',
            'min_interval_seconds' => 120,
            'clock_offset_minutes' => -60,
        ]);
    }

    public function test_an_out_of_range_interval_is_refused(): void
    {
        $id = $this->registered();

        $this->asAdmin()->postJson('/v1/devices/update', [
            'device_id' => $id,
            'min_interval_seconds' => 99999,
        ])->assertStatus(422)->assertJsonPath('error_code', 'min_interval_range');
    }

    public function test_a_device_cannot_be_unclaimed_through_the_settings(): void
    {
        // Releasing it is its own action, so the users and queued commands are
        // cleaned up with it.
        $id = $this->registered();

        $this->asAdmin()->postJson('/v1/devices/update', [
            'device_id' => $id,
            'status' => 'unclaimed',
        ])->assertStatus(422)->assertJsonPath('error_code', 'invalid_status');
    }

    public function test_releasing_keeps_the_attendance_and_drops_the_link(): void
    {
        // Those hours were worked, and they belong to the company rather than
        // to the hardware.
        $id = $this->registered();
        DB::table('device_users')->insert([
            'tenant_id' => $this->tenantId,
            'device_id' => $id,
            'device_user_id' => '7',
        ]);
        DB::table('device_punches')->insert([
            'tenant_id' => $this->tenantId,
            'device_id' => $id,
            'device_user_id' => '7',
            'punched_at' => TenantClock::timestamp($this->tenantId),
            'state' => 'applied',
        ]);

        $this->asAdmin()->postJson('/v1/devices/delete', ['device_id' => $id])->assertOk();

        $this->assertDatabaseHas('attendance_devices', ['id' => $id, 'status' => 'unclaimed', 'tenant_id' => null]);
        $this->assertDatabaseMissing('device_users', ['device_id' => $id]);
        $this->assertDatabaseHas('device_punches', ['device_id' => $id]);
    }

    public function test_a_command_waits_for_the_device_to_collect_it(): void
    {
        // We never dial the device — it lives behind the customer's router.
        $id = $this->registered();

        $this->asAdmin()->postJson('/v1/devices/command', [
            'device_id' => $id,
            'kind' => 'sync_time',
        ])->assertOk()->assertJsonStructure(['data' => ['command_id', 'recent']]);

        $this->assertDatabaseHas('device_commands', [
            'device_id' => $id,
            'kind' => 'sync_time',
            'state' => 'queued',
        ]);
    }

    public function test_an_unsupported_command_is_refused(): void
    {
        $id = $this->registered();

        $this->asAdmin()->postJson('/v1/devices/command', [
            'device_id' => $id,
            'kind' => 'self_destruct',
        ])->assertStatus(422)->assertJsonPath('error_code', 'UNSUPPORTED_COMMAND');
    }

    // ── Matching User IDs to people ──────────────────────────────────────

    private function deviceUser(int $deviceId, string $deviceUserId = '7'): int
    {
        return (int) DB::table('device_users')->insertGetId([
            'tenant_id' => $this->tenantId,
            'device_id' => $deviceId,
            'device_user_id' => $deviceUserId,
        ]);
    }

    public function test_unlinked_ids_sort_first(): void
    {
        // That list is the setup task, and it shrinks to nothing as HR works
        // through it.
        $deviceId = $this->registered();
        $linked = $this->deviceUser($deviceId, '3');
        $unlinked = $this->deviceUser($deviceId, '9');
        DB::table('device_users')->where('id', $linked)->update(['employee_id' => $this->employeeId]);

        $users = $this->asAdmin()->getJson('/v1/devices/users?device_id='.$deviceId)
            ->assertOk()->json('data.users');

        $this->assertIsArray($users);
        $this->assertIsArray($users[0]);
        $this->assertSame($unlinked, Value::int($users[0]['id']));
    }

    public function test_linking_replays_the_punches_that_arrived_first(): void
    {
        // Without this the first day of a new device — when everyone is
        // enrolled and everyone taps — is lost while HR is still matching
        // names to numbers.
        $deviceId = $this->registered();
        $rowId = $this->deviceUser($deviceId);
        $today = TenantClock::date($this->tenantId);

        DB::table('device_punches')->insert([
            'tenant_id' => $this->tenantId,
            'device_id' => $deviceId,
            'device_user_id' => '7',
            'punched_at' => $today.' 08:05:00',
            'state' => 'unmatched',
        ]);

        $this->asAdmin()->postJson('/v1/devices/link-user', [
            'device_user_row_id' => $rowId,
            'employee_id' => $this->employeeId,
        ])->assertOk()->assertJsonPath('data.replayed.applied', 1);

        $this->assertDatabaseHas('attendance', [
            'employee_id' => $this->employeeId,
            'date' => $today,
            'check_in_time' => '08:05:00',
            'check_in_method' => 'device',
        ]);
        $this->assertDatabaseHas('device_punches', ['device_user_id' => '7', 'state' => 'applied']);
    }

    public function test_one_person_cannot_hold_two_ids_on_the_same_device(): void
    {
        // Two User IDs pointing at the same employee would fight over the same
        // attendance row all day.
        $deviceId = $this->registered();
        $first = $this->deviceUser($deviceId, '7');
        $second = $this->deviceUser($deviceId, '8');

        DB::table('device_users')->where('id', $first)->update(['employee_id' => $this->employeeId]);

        $this->asAdmin()->postJson('/v1/devices/link-user', [
            'device_user_row_id' => $second,
            'employee_id' => $this->employeeId,
        ])->assertStatus(409)->assertJsonPath('error_code', 'EMPLOYEE_ALREADY_LINKED');
    }

    public function test_unlinking_leaves_the_row_in_place(): void
    {
        $deviceId = $this->registered();
        $rowId = $this->deviceUser($deviceId);
        DB::table('device_users')->where('id', $rowId)->update(['employee_id' => $this->employeeId]);

        $this->asAdmin()->postJson('/v1/devices/link-user', ['device_user_row_id' => $rowId])
            ->assertOk()->assertJsonPath('data.message', 'User unlinked');

        $this->assertDatabaseHas('device_users', ['id' => $rowId, 'employee_id' => null, 'linked_at' => null]);
    }

    // ── Importing a file ─────────────────────────────────────────────────

    private function csv(string $body): UploadedFile
    {
        return UploadedFile::fake()->createWithContent('punches.csv', $body);
    }

    public function test_a_preview_commits_nothing(): void
    {
        // Bulk imports are the one place a mistake is expensive and invisible.
        $today = TenantClock::date($this->tenantId);

        $this->asAdmin()->post('/v1/devices/import-punches', [
            'branch_id' => $this->branchId,
            'preview' => true,
            'file' => $this->csv("UserID,DateTime\n7,{$today} 08:05:00\n"),
        ])
            ->assertOk()
            ->assertJsonPath('data.preview', true)
            ->assertJsonPath('data.readable_rows', 1);

        $this->assertDatabaseMissing('device_punches', ['device_user_id' => '7']);
    }

    public function test_an_import_creates_a_stand_in_device_for_the_branch(): void
    {
        // A punch has to belong to a device row — that is what carries the
        // branch, the clock offset and the repeat-tap window.
        $today = TenantClock::date($this->tenantId);

        $this->asAdmin()->post('/v1/devices/import-punches', [
            'branch_id' => $this->branchId,
            'file' => $this->csv("UserID,DateTime\n7,{$today} 08:05:00\n"),
        ])->assertOk()->assertJsonPath('data.read_rows', 1);

        $this->assertDatabaseHas('attendance_devices', [
            'serial_number' => AttendanceDevice::normaliseSerial("FILE-T{$this->tenantId}-B{$this->branchId}"),
            'tenant_id' => $this->tenantId,
        ]);
    }

    public function test_an_unlinked_id_lands_unmatched_rather_than_failing(): void
    {
        // The expected outcome of a first import, not an error.
        $today = TenantClock::date($this->tenantId);

        $this->asAdmin()->post('/v1/devices/import-punches', [
            'branch_id' => $this->branchId,
            'file' => $this->csv("UserID,DateTime\n7,{$today} 08:05:00\n"),
        ])
            ->assertOk()
            ->assertJsonPath('data.results.unmatched', 1)
            ->assertJsonPath('data.unlinked_users', 1);
    }

    public function test_a_linked_id_is_written_straight_to_attendance(): void
    {
        // After the working day the punches describe. The ingestor refuses a
        // timestamp more than twelve hours ahead as a misconfigured device
        // clock, so a 17:30 punch is out of range if the suite runs at 01:00.
        $this->travelTo(TenantClock::now($this->tenantId)->setTime(20, 0));

        $today = TenantClock::date($this->tenantId);
        $device = AttendanceDevice::ensureFileImportDevice($this->tenantId, $this->branchId, null);
        DB::table('device_users')->insert([
            'tenant_id' => $this->tenantId,
            'device_id' => Value::int($device['id']),
            'device_user_id' => '7',
            'employee_id' => $this->employeeId,
        ]);

        $this->asAdmin()->post('/v1/devices/import-punches', [
            'branch_id' => $this->branchId,
            'file' => $this->csv("UserID,DateTime\n7,{$today} 08:05:00\n7,{$today} 17:30:00\n"),
        ])->assertOk()->assertJsonPath('data.results.applied', 2);

        $this->assertDatabaseHas('attendance', [
            'employee_id' => $this->employeeId,
            'date' => $today,
            'check_in_time' => '08:05:00',
            'check_out_time' => '17:30:00',
        ]);
    }

    public function test_re_importing_the_same_export_does_not_double_count(): void
    {
        // The obvious way to catch up is to export everything again.
        $today = TenantClock::date($this->tenantId);
        $body = "UserID,DateTime\n7,{$today} 08:05:00\n";

        $this->asAdmin()->post('/v1/devices/import-punches', [
            'branch_id' => $this->branchId,
            'file' => $this->csv($body),
        ])->assertOk();

        $this->asAdmin()->post('/v1/devices/import-punches', [
            'branch_id' => $this->branchId,
            'file' => $this->csv($body),
        ])->assertOk()->assertJsonPath('data.already_imported', 1);

        $this->assertSame(1, DB::table('device_punches')->where('device_user_id', '7')->count());
    }

    public function test_a_file_nothing_can_be_read_from_says_why(): void
    {
        // Almost always the wrong column was taken for the id or the date;
        // saying so beats reporting "0 imported".
        $this->asAdmin()->post('/v1/devices/import-punches', [
            'branch_id' => $this->branchId,
            'file' => $this->csv("Notes\nsomething\nelse\n"),
        ])->assertStatus(422)->assertJsonPath('error_code', 'NO_READABLE_ROWS');
    }

    public function test_an_import_needs_somewhere_to_put_the_punches(): void
    {
        $this->asAdmin()->post('/v1/devices/import-punches', [
            'file' => $this->csv("UserID,DateTime\n7,2026-08-30 08:05:00\n"),
        ])->assertStatus(422)->assertJsonPath('error_code', 'BRANCH_REQUIRED');
    }

    public function test_an_empty_upload_is_refused(): void
    {
        $this->asAdmin()->post('/v1/devices/import-punches', ['branch_id' => $this->branchId])
            ->assertStatus(422)->assertJsonPath('error_code', 'FILE_REQUIRED');
    }

    public function test_a_punch_from_a_terminal_with_a_broken_clock_is_quarantined(): void
    {
        // A device stuck in 2001 is a hardware fault, not attendance.
        $device = AttendanceDevice::ensureFileImportDevice($this->tenantId, $this->branchId, null);
        DB::table('device_users')->insert([
            'tenant_id' => $this->tenantId,
            'device_id' => Value::int($device['id']),
            'device_user_id' => '7',
            'employee_id' => $this->employeeId,
        ]);

        $this->asAdmin()->post('/v1/devices/import-punches', [
            'branch_id' => $this->branchId,
            'file' => $this->csv("UserID,DateTime\n7,2001-01-01 08:05:00\n"),
        ])->assertOk()->assertJsonPath('data.results.ignored', 1);

        $this->assertDatabaseMissing('attendance', ['employee_id' => $this->employeeId, 'date' => '2001-01-01']);
    }

    public function test_a_second_tap_within_the_dead_time_is_not_a_second_punch(): void
    {
        $today = TenantClock::date($this->tenantId);
        $device = AttendanceDevice::ensureFileImportDevice($this->tenantId, $this->branchId, null);
        DB::table('attendance_devices')->where('id', Value::int($device['id']))
            ->update(['min_interval_seconds' => 300]);
        DB::table('device_users')->insert([
            'tenant_id' => $this->tenantId,
            'device_id' => Value::int($device['id']),
            'device_user_id' => '7',
            'employee_id' => $this->employeeId,
        ]);

        $this->asAdmin()->post('/v1/devices/import-punches', [
            'branch_id' => $this->branchId,
            'file' => $this->csv("UserID,DateTime\n7,{$today} 08:05:00\n7,{$today} 08:06:00\n"),
        ])->assertOk()->assertJsonPath('data.results.duplicate', 1);
    }

    public function test_importing_needs_the_attendance_permission(): void
    {
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->post('/v1/devices/import-punches', [
                'branch_id' => $this->branchId,
                'file' => $this->csv("UserID,DateTime\n7,2026-08-30 08:05:00\n"),
            ])->assertForbidden();
    }
}
