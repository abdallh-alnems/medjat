<?php

declare(strict_types=1);

namespace Tests\Feature\Attendance;

use App\Models\Admin;
use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\CreatesFixtures;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\TestCase;

/**
 * The employee's own month, and the management-side method override.
 */
final class MyAttendanceTest extends TestCase
{
    use CreatesFixtures;
    use DatabaseTransactions;

    private Employee $employee;

    private int $branchId;

    private string $token;

    private FakeFirebaseTokenVerifier $firebase;

    protected function setUp(): void
    {
        parent::setUp();
        TenantClock::flush();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);

        $this->employee = $this->createEmployee($this->createTenant());

        $this->branchId = (int) $this->employee->branch_id;

        DB::table('branches')->where('id', $this->branchId)->update([
            'latitude' => 30.0444, 'longitude' => 31.2357, 'gps_radius_meters' => 150,
        ]);
        DB::table('tenants')->where('id', $this->employee->tenant_id)->update([
            'attendance_methods' => json_encode(['gps_only']),
            'require_local_biometric' => 0,
        ]);
        Employee::query()->whereKey($this->employee->id)->update(['attendance_methods' => null]);

        $plain = 'test-'.bin2hex(random_bytes(16));
        EmployeeAuthToken::query()->create([
            'tenant_id' => $this->employee->tenant_id,
            'employee_id' => $this->employee->id,
            'token_hash' => EmployeeAuthToken::hash($plain),
            'platform' => 'android',
            'device_id' => 'device-a',
        ]);
        $this->token = $plain;
    }

    public function test_the_month_comes_back_with_everything_the_home_screen_needs(): void
    {
        // One call rather than three: the app makes it on launch and most of the
        // answers are "no".
        $this->withHeader('X-Employee-Token', $this->token)
            ->getJson('/v1/attendance/mine')
            ->assertOk()
            ->assertJsonStructure(['data' => [
                'records', 'month', 'employee_id',
                'attendance_config' => [
                    'branch_id', 'branch_name', 'methods', 'gps_radius_meters',
                    'allow_offline', 'require_local_biometric', 'branch_lat', 'branch_lng',
                    'is_crew_supervisor',
                ],
                'today_shift' => ['start_time', 'end_time', 'shift_name', 'is_rest_day'],
            ]])
            ->assertJsonPath('data.attendance_config.gps_radius_meters', 150);
    }

    public function test_a_branchless_employee_gets_a_null_config_not_a_half_populated_one(): void
    {
        // Matches what crew check-in does: no branch means no geofence to verify
        // against, so offering the buttons would be a dead end.
        Employee::query()->whereKey($this->employee->id)->update(['branch_id' => null]);

        $this->withHeader('X-Employee-Token', $this->token)
            ->getJson('/v1/attendance/mine')
            ->assertOk()
            ->assertJsonPath('data.attendance_config', null);
    }

    public function test_the_month_defaults_to_the_companys_current_month(): void
    {
        $this->withHeader('X-Employee-Token', $this->token)
            ->getJson('/v1/attendance/mine')
            ->assertOk()
            ->assertJsonPath('data.month', TenantClock::now($this->employee->tenant_id)->format('Y-m'));
    }

    public function test_a_published_rest_day_is_distinguishable_from_having_no_schedule(): void
    {
        // A cell naming no shift is an explicit rest day; no cell at all means
        // the standing hours apply. Collapsing the two would tell somebody they
        // are off when nobody said so.
        DB::table('employee_shift_schedule')->insert([
            'tenant_id' => $this->employee->tenant_id,
            'employee_id' => $this->employee->id,
            'work_date' => TenantClock::date($this->employee->tenant_id),
            'shift_id' => null,
            'status' => 'published',
        ]);

        $this->withHeader('X-Employee-Token', $this->token)
            ->getJson('/v1/attendance/mine')
            ->assertOk()
            ->assertJsonPath('data.today_shift.is_rest_day', true)
            ->assertJsonPath('data.today_shift.start_time', null);
    }

    public function test_a_draft_schedule_cell_is_ignored(): void
    {
        // A draft is a manager still thinking.
        DB::table('employee_shift_schedule')->insert([
            'tenant_id' => $this->employee->tenant_id,
            'employee_id' => $this->employee->id,
            'work_date' => TenantClock::date($this->employee->tenant_id),
            'shift_id' => null,
            'status' => 'draft',
        ]);

        $this->withHeader('X-Employee-Token', $this->token)
            ->getJson('/v1/attendance/mine')
            ->assertOk()
            ->assertJsonPath('data.today_shift.is_rest_day', false);
    }

    // ── Method override ──────────────────────────────────────────────────

    /** @return array{Admin, string} */
    private function admin(string $role = 'general_manager'): array
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        $id = Admin::query()->insertGetId([
            'firebase_uid' => $uid,
            'tenant_id' => $this->employee->tenant_id,
            'name' => 'Test Admin',
            'role' => $role,
            'is_active' => 1,
        ]);

        return [Admin::query()->findOrFail($id), $this->firebase->issue($uid)];
    }

    public function test_an_override_is_stored_for_an_employee(): void
    {
        [, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/method-override', [
                'scope_type' => 'employee',
                'scope_id' => $this->employee->id,
                'attendance_methods' => ['gps_only', 'face_selfie'],
            ])->assertOk();

        $stored = json_decode(
            Value::string(DB::table('employees')->where('id', $this->employee->id)->value('attendance_methods')),
            true
        );
        $this->assertEqualsCanonicalizing(['gps_only', 'face_selfie'], $stored);
    }

    public function test_null_clears_the_override_back_to_inheriting(): void
    {
        // Different from an empty list, which would be a scope permitting
        // nothing at all — nobody sets that on purpose.
        [, $token] = $this->admin();
        Employee::query()->whereKey($this->employee->id)
            ->update(['attendance_methods' => json_encode(['gps_only'])]);

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/method-override', [
                'scope_type' => 'employee',
                'scope_id' => $this->employee->id,
                'attendance_methods' => null,
            ])->assertOk();

        $this->assertNull(DB::table('employees')->where('id', $this->employee->id)->value('attendance_methods'));
    }

    public function test_an_empty_list_is_refused(): void
    {
        [, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/method-override', [
                'scope_type' => 'employee',
                'scope_id' => $this->employee->id,
                'attendance_methods' => [],
            ])->assertStatus(422)->assertJsonPath('error_code', 'attendance_methods_non_empty_array');
    }

    public function test_an_unknown_method_is_refused(): void
    {
        [, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/method-override', [
                'scope_type' => 'employee',
                'scope_id' => $this->employee->id,
                'attendance_methods' => ['telepathy'],
            ])->assertStatus(422)->assertJsonPath('error_code', 'invalid_attendance_method');
    }

    public function test_a_scope_that_does_not_exist_is_a_404_not_a_silent_no_op(): void
    {
        // The caller believes they configured something.
        [, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/method-override', [
                'scope_type' => 'employee',
                'scope_id' => 999999,
                'attendance_methods' => ['gps_only'],
            ])->assertNotFound();
    }

    public function test_an_admin_without_the_permission_is_refused(): void
    {
        [, $token] = $this->admin('attendance');

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/method-override', [
                'scope_type' => 'employee',
                'scope_id' => $this->employee->id,
                'attendance_methods' => ['gps_only'],
            ])->assertForbidden()->assertJsonPath('error_code', 'missing_permission');
    }

    public function test_the_change_is_audited(): void
    {
        [$admin, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/method-override', [
                'scope_type' => 'employee',
                'scope_id' => $this->employee->id,
                'attendance_methods' => ['gps_only'],
            ])->assertOk();

        $this->assertDatabaseHas('audit_log', [
            'admin_id' => $admin->id,
            'action' => 'attendance.set_method_override',
            'target_type' => 'employee',
        ]);
    }
}
