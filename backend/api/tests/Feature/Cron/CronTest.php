<?php

declare(strict_types=1);

namespace Tests\Feature\Cron;

use App\Modules\Notifications\Domain\PushSender;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * The scheduled jobs: the daily digest, the absence safety net, and the
 * retention purge.
 */
final class CronTest extends TestCase
{
    use DatabaseTransactions;

    private const SECRET = 'test-cron-secret';

    private int $tenantId;

    private int $branchId;

    private int $adminId;

    private string $today;

    protected function setUp(): void
    {
        parent::setUp();
        TenantClock::flush();

        Config::set('medjat.cron.secret', self::SECRET);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));
        $this->today = TenantClock::date($this->tenantId);

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId, 'name' => 'Cron branch', 'is_active' => 1,
        ]);

        // The dump's own employees would otherwise flood every digest.
        DB::table('employees')->where('tenant_id', $this->tenantId)
            ->where('status', 'active')->update(['status' => 'suspended']);
        DB::table('notifications')->where('tenant_id', $this->tenantId)->delete();

        // One recipient, so the counts in the response are a fact about the
        // job rather than about how many managers the dump happens to hold.
        DB::table('admins')->where('tenant_id', $this->tenantId)->update(['is_active' => 0]);

        $this->adminId = (int) DB::table('admins')->insertGetId([
            'firebase_uid' => 'uid-'.bin2hex(random_bytes(6)),
            'tenant_id' => $this->tenantId,
            'name' => 'Alert recipient',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);
    }

    private function employee(string $name, ?string $end = '17:00:00'): int
    {
        return (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'name' => $name,
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
            'work_start_time' => '09:00:00',
            'work_end_time' => $end,
        ]);
    }

    /**
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function fire(string $path, ?string $key = self::SECRET): TestResponse
    {
        return $this->getJson($path.($key === null ? '' : '?key='.$key));
    }

    /**
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function alerts(): TestResponse
    {
        return $this->fire('/v1/cron/run-alerts');
    }

    private function alertCount(string $type = 'attendance'): int
    {
        return DB::table('notifications')
            ->where('tenant_id', $this->tenantId)->where('type', $type)->count();
    }

    public function test_a_request_without_the_secret_is_refused(): void
    {
        $this->fire('/v1/cron/run-alerts', null)->assertStatus(403);
        $this->fire('/v1/cron/run-alerts', 'wrong-secret')->assertStatus(403);
    }

    public function test_an_unset_secret_refuses_everything(): void
    {
        // A missing environment variable must not become an open door on
        // endpoints that terminate employees and delete photographs.
        Config::set('medjat.cron.secret', '');

        $this->fire('/v1/cron/run-alerts')->assertStatus(403);
        $this->fire('/v1/cron/run-alerts', '')->assertStatus(403);
    }

    public function test_the_crontabs_other_parameter_name_is_accepted_too(): void
    {
        // The installed crontab passes both; the code adapts to what is
        // deployed rather than the other way round.
        $this->getJson('/v1/cron/run-alerts?cron_secret='.self::SECRET)->assertOk();
    }

    public function test_lateness_reaches_the_people_who_can_act_on_it(): void
    {
        $employee = $this->employee('Late arrival');
        DB::table('attendance')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $employee,
            'branch_id' => $this->branchId,
            'date' => $this->today,
            'check_in_time' => '09:30:00',
            'status' => 'present',
            'late_minutes' => 30,
        ]);

        $this->alerts()->assertOk()->assertJsonPath('data.alerts_sent.late_absence', 1);

        $this->assertDatabaseHas('notifications', [
            'tenant_id' => $this->tenantId,
            'admin_id' => $this->adminId,
            'type' => 'attendance',
        ]);
    }

    public function test_the_same_problem_is_only_reported_once_a_day(): void
    {
        // An alert stream that repeats is one people learn to swipe away — and
        // then the one that mattered goes with it.
        $employee = $this->employee('Absent today');
        DB::table('attendance')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $employee,
            'branch_id' => $this->branchId,
            'date' => $this->today,
            'status' => 'absent',
        ]);

        $this->alerts()->assertOk()->assertJsonPath('data.alerts_sent.late_absence', 1);
        $this->alerts()->assertOk()->assertJsonPath('data.alerts_sent.late_absence', 0);

        $this->assertSame(1, $this->alertCount());
    }

    public function test_a_recipient_who_turned_the_alert_off_is_not_told(): void
    {
        DB::table('admin_notification_prefs')->insert([
            'admin_id' => $this->adminId,
            'prefs' => json_encode(['late_absence' => false]),
        ]);

        $employee = $this->employee('Absent again');
        DB::table('attendance')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $employee,
            'branch_id' => $this->branchId,
            'date' => $this->today,
            'status' => 'absent',
        ]);

        $this->alerts()->assertOk()->assertJsonPath('data.alerts_sent.late_absence', 0);
        $this->assertSame(0, $this->alertCount());
    }

    public function test_a_new_alert_type_reaches_everybody_until_it_is_turned_off(): void
    {
        // Absent means yes: the opposite default means a new alert silently
        // reaches nobody until each person opts in.
        DB::table('admin_notification_prefs')->insert([
            'admin_id' => $this->adminId,
            'prefs' => json_encode(['some_other_alert' => false]),
        ]);

        $employee = $this->employee('Absent once more');
        DB::table('attendance')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $employee,
            'branch_id' => $this->branchId,
            'date' => $this->today,
            'status' => 'absent',
        ]);

        $this->alerts()->assertOk()->assertJsonPath('data.alerts_sent.late_absence', 1);
    }

    public function test_a_missing_checkout_waits_until_the_day_has_ended(): void
    {
        // Their day is not over yet, so there is nothing to report.
        $employee = $this->employee('Still working', '23:59:00');
        DB::table('attendance')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $employee,
            'branch_id' => $this->branchId,
            'date' => $this->today,
            'check_in_time' => '09:00:00',
            'status' => 'present',
        ]);

        $this->alerts()->assertOk()->assertJsonPath('data.alerts_sent.missing_checkout', 0);
    }

    public function test_a_missing_checkout_is_reported_once_the_day_has_ended(): void
    {
        $employee = $this->employee('Forgot to leave', '00:01:00');
        DB::table('attendance')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $employee,
            'branch_id' => $this->branchId,
            'date' => $this->today,
            'check_in_time' => '00:00:00',
            'status' => 'present',
        ]);

        $this->alerts()->assertOk()->assertJsonPath('data.alerts_sent.missing_checkout', 1);
    }

    public function test_a_fixed_term_ending_soon_is_flagged(): void
    {
        $employee = $this->employee('Contract ending');
        DB::table('employees')->where('id', $employee)->update([
            'auto_terminate_at' => TenantClock::now($this->tenantId)->modify('+3 days')->format('Y-m-d'),
        ]);

        $this->alerts()->assertOk()->assertJsonPath('data.alerts_sent.employment_ending', 1);

        // Warned, not terminated — the date has not passed.
        $this->assertDatabaseHas('employees', ['id' => $employee, 'status' => 'active']);
    }

    public function test_a_fixed_term_that_has_passed_ends_the_employment(): void
    {
        $employee = $this->employee('Contract expired');
        DB::table('employees')->where('id', $employee)->update([
            'auto_terminate_at' => TenantClock::now($this->tenantId)->modify('-1 day')->format('Y-m-d'),
        ]);

        $this->alerts()->assertOk()->assertJsonPath('data.alerts_sent.employment_terminated', 1);

        $this->assertDatabaseHas('employees', ['id' => $employee, 'status' => 'terminated']);
        $this->assertDatabaseHas('audit_log', [
            'tenant_id' => $this->tenantId,
            'action' => 'employee.auto_terminate',
            'target_id' => (string) $employee,
        ]);
    }

    public function test_a_termination_is_only_announced_once(): void
    {
        $employee = $this->employee('Contract expired twice');
        DB::table('employees')->where('id', $employee)->update([
            'auto_terminate_at' => TenantClock::now($this->tenantId)->modify('-1 day')->format('Y-m-d'),
        ]);

        $this->alerts()->assertOk()->assertJsonPath('data.alerts_sent.employment_terminated', 1);
        $this->alerts()->assertOk()->assertJsonPath('data.alerts_sent.employment_terminated', 0);
    }

    public function test_a_silent_kiosk_is_reported(): void
    {
        // The people who depend on a kiosk are the ones with no phone to fall
        // back on.
        DB::table('attendance_stations')->insert([
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'name' => 'Front desk tablet',
            'status' => 'active',
            'last_seen_at' => DB::raw('DATE_SUB(NOW(), INTERVAL 3 HOUR)'),
        ]);

        $this->alerts()->assertOk()->assertJsonPath('data.alerts_sent.kiosk_offline', 1);
    }

    public function test_a_kiosk_that_was_never_seen_is_not_reported_as_offline(): void
    {
        // The row is created at pairing with last_seen_at set, so a null means
        // the pairing went wrong — a different problem, and a different alert.
        DB::table('attendance_stations')->insert([
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'name' => 'Never paired',
            'status' => 'active',
            'last_seen_at' => null,
        ]);

        $this->alerts()->assertOk()->assertJsonPath('data.alerts_sent.kiosk_offline', 0);
    }

    public function test_the_absence_catch_up_marks_a_completed_day(): void
    {
        $employee = $this->employee('Never showed up');
        $yesterday = TenantClock::now($this->tenantId)->modify('-1 day')->format('Y-m-d');

        $this->fire('/v1/cron/catch-up-absences')->assertOk()->assertJsonPath('data.status', 'success');

        $this->assertDatabaseHas('attendance', [
            'employee_id' => $employee, 'date' => $yesterday, 'status' => 'absent',
        ]);
    }

    public function test_the_absence_catch_up_can_be_run_twice(): void
    {
        $this->employee('Never showed up either');

        $this->fire('/v1/cron/catch-up-absences')->assertOk();
        $before = DB::table('attendance')->where('tenant_id', $this->tenantId)->count();

        $this->fire('/v1/cron/catch-up-absences')->assertOk();

        // Idempotent through the unique key on (employee_id, date).
        $this->assertSame($before, DB::table('attendance')->where('tenant_id', $this->tenantId)->count());
    }

    public function test_the_purge_deletes_an_expired_capture_and_its_pointer(): void
    {
        Storage::fake('uploads');
        Storage::disk('uploads')->put('kiosk/expired.jpg', 'image-bytes');

        $stationId = (int) DB::table('attendance_stations')->insertGetId([
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'name' => 'Capture station',
            'status' => 'active',
        ]);

        $logId = (int) DB::table('station_recognition_logs')->insertGetId([
            'tenant_id' => $this->tenantId,
            'station_id' => $stationId,
            'branch_id' => $this->branchId,
            'result' => 'matched',
            'capture_path' => 'uploads/kiosk/expired.jpg',
            'capture_expires_at' => DB::raw('DATE_SUB(NOW(), INTERVAL 1 DAY)'),
        ]);

        $this->fire('/v1/cron/purge-kiosk-captures')
            ->assertOk()
            ->assertJsonPath('data.deleted', 1);

        Storage::disk('uploads')->assertMissing('kiosk/expired.jpg');
        // The row survives: its scores are what threshold tuning reads, and
        // they carry no biometric content.
        $this->assertDatabaseHas('station_recognition_logs', ['id' => $logId, 'capture_path' => null]);
    }

    public function test_a_capture_still_inside_its_window_is_kept(): void
    {
        Storage::fake('uploads');
        Storage::disk('uploads')->put('kiosk/fresh.jpg', 'image-bytes');

        $stationId = (int) DB::table('attendance_stations')->insertGetId([
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'name' => 'Fresh station',
            'status' => 'active',
        ]);

        DB::table('station_recognition_logs')->insert([
            'tenant_id' => $this->tenantId,
            'station_id' => $stationId,
            'branch_id' => $this->branchId,
            'result' => 'matched',
            'capture_path' => 'uploads/kiosk/fresh.jpg',
            'capture_expires_at' => DB::raw('DATE_ADD(NOW(), INTERVAL 30 DAY)'),
        ]);

        $this->fire('/v1/cron/purge-kiosk-captures')->assertOk()->assertJsonPath('data.deleted', 0);

        Storage::disk('uploads')->assertExists('kiosk/fresh.jpg');
    }

    public function test_a_path_that_escapes_the_capture_directory_is_not_deleted(): void
    {
        Storage::fake('uploads');

        $stationId = (int) DB::table('attendance_stations')->insertGetId([
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'name' => 'Suspicious station',
            'status' => 'active',
        ]);

        $logId = (int) DB::table('station_recognition_logs')->insertGetId([
            'tenant_id' => $this->tenantId,
            'station_id' => $stationId,
            'branch_id' => $this->branchId,
            'result' => 'matched',
            'capture_path' => 'uploads/payslips/secret.pdf',
            'capture_expires_at' => DB::raw('DATE_SUB(NOW(), INTERVAL 1 DAY)'),
        ]);

        // The pointer is dropped so it stops being selected, but nothing is
        // unlinked — a stored path that escapes its directory is a bug worth
        // leaving evidence of on disk.
        $this->fire('/v1/cron/purge-kiosk-captures')
            ->assertOk()
            ->assertJsonPath('data.deleted', 0)
            ->assertJsonPath('data.failed', 1);

        $this->assertDatabaseHas('station_recognition_logs', ['id' => $logId, 'capture_path' => null]);
    }

    public function test_stale_qr_challenges_are_cleaned_up_on_the_same_pass(): void
    {
        Storage::fake('uploads');

        DB::insert(
            'INSERT INTO branch_qr_challenges (tenant_id, branch_id, nonce, expires_at)'
            .' VALUES (?, ?, ?, DATE_SUB(NOW(), INTERVAL 3 DAY))',
            [$this->tenantId, $this->branchId, bin2hex(random_bytes(16))],
        );

        $this->fire('/v1/cron/purge-kiosk-captures')
            ->assertOk()
            ->assertJsonPath('data.qr_challenges_purged', 1);
    }

    public function test_a_recent_qr_challenge_is_kept_for_a_day_of_slack(): void
    {
        Storage::fake('uploads');

        // A punch disputed this morning must still be traceable to the code
        // that produced it.
        DB::insert(
            'INSERT INTO branch_qr_challenges (tenant_id, branch_id, nonce, expires_at)'
            .' VALUES (?, ?, ?, DATE_SUB(NOW(), INTERVAL 2 HOUR))',
            [$this->tenantId, $this->branchId, bin2hex(random_bytes(16))],
        );

        $this->fire('/v1/cron/purge-kiosk-captures')
            ->assertOk()
            ->assertJsonPath('data.qr_challenges_purged', 0);
    }
}
