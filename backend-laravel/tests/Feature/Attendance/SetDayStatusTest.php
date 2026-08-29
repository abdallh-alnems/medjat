<?php

declare(strict_types=1);

namespace Tests\Feature\Attendance;

use App\Domain\Time\TenantClock;
use App\Models\Admin;
use App\Models\CustomRole;
use App\Models\Employee;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\TestCase;

/**
 * A manager setting what a day was, after the fact.
 *
 * The delicate part is that attendance and leaves have to stay in step: a day
 * marked as leave that never reaches the leaves table means the balance quietly
 * stops matching the sheet, and a day moved off leave that keeps its row holds a
 * day the employee never took.
 */
final class SetDayStatusTest extends TestCase
{
    use DatabaseTransactions;

    private const ENDPOINT = '/app/attendance/set_day_status.php';

    private Employee $employee;

    private int $tenantId;

    private string $date;

    private FakeFirebaseTokenVerifier $firebase;

    protected function setUp(): void
    {
        parent::setUp();
        TenantClock::flush();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);

        $this->employee = Employee::query()
            ->where('status', 'active')
            ->whereNotNull('branch_id')
            ->firstOrFail();

        $this->tenantId = $this->employee->tenant_id;
        $this->date = TenantClock::now($this->tenantId)->modify('-2 days')->format('Y-m-d');

        DB::table('attendance')->where('employee_id', $this->employee->id)->where('date', $this->date)->delete();
        DB::table('leaves')->where('employee_id', $this->employee->id)->where('date', $this->date)->delete();
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array{Admin, string}
     */
    private function admin(array $overrides = []): array
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        $id = Admin::query()->insertGetId(array_merge([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Manager',
            'role' => 'general_manager',
            'is_active' => 1,
        ], $overrides));

        return [Admin::query()->findOrFail($id), $this->firebase->issue($uid)];
    }

    /**
     * @param  array<string, mixed>  $body
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function set(string $token, array $body): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $token)
            ->postJson(self::ENDPOINT, array_merge([
                'employee_id' => $this->employee->id,
                'date' => $this->date,
            ], $body));
    }

    public function test_a_present_day_records_its_times_and_derived_minutes(): void
    {
        [, $token] = $this->admin();
        Employee::query()->whereKey($this->employee->id)
            ->update(['work_start_time' => '09:00:00', 'work_end_time' => '17:00:00']);

        $this->set($token, [
            'status' => 'present',
            'check_in_time' => '09:30',
            'check_out_time' => '18:00',
        ])->assertOk()->assertJsonPath('data.record.status', 'present');

        $row = DB::table('attendance')->where('employee_id', $this->employee->id)
            ->where('date', $this->date)->first();

        $this->assertNotNull($row);
        $this->assertSame(30, Value::int($row->late_minutes));
        $this->assertSame(60, Value::int($row->overtime_minutes));
        $this->assertSame(510, Value::int($row->worked_minutes));
        $this->assertSame('manual', $row->check_in_method);
    }

    public function test_a_check_out_before_the_check_in_is_refused(): void
    {
        [, $token] = $this->admin();

        $this->set($token, [
            'status' => 'present',
            'check_in_time' => '17:00',
            'check_out_time' => '09:00',
        ])->assertStatus(422)->assertJsonPath('error_code', 'check_out_time_after_check');
    }

    public function test_a_malformed_time_is_refused(): void
    {
        [, $token] = $this->admin();

        $this->set($token, ['status' => 'present', 'check_in_time' => 'half past nine'])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'invalid_time_format_expected_hh');
    }

    public function test_times_are_dropped_on_a_day_nobody_was_present(): void
    {
        // They only mean anything on a present day.
        [, $token] = $this->admin();

        $this->set($token, ['status' => 'absent', 'check_in_time' => '09:00'])->assertOk();

        $this->assertNull(
            DB::table('attendance')->where('employee_id', $this->employee->id)
                ->where('date', $this->date)->value('check_in_time')
        );
    }

    public function test_marking_a_day_as_leave_also_books_the_leave(): void
    {
        // Without this the balance quietly stops matching the sheet.
        [, $token] = $this->admin();

        $this->set($token, ['status' => 'leave', 'leave_type' => 'sick'])->assertOk();

        $this->assertDatabaseHas('leaves', [
            'employee_id' => $this->employee->id,
            'date' => $this->date,
            'type' => 'sick',
            'status' => 'approved',
        ]);
    }

    public function test_moving_a_day_off_leave_releases_it(): void
    {
        [, $token] = $this->admin();

        $this->set($token, ['status' => 'leave'])->assertOk();
        $this->set($token, ['status' => 'present', 'check_in_time' => '09:00'])->assertOk();

        $this->assertDatabaseMissing('leaves', [
            'employee_id' => $this->employee->id,
            'date' => $this->date,
        ]);
    }

    public function test_a_multi_day_request_is_left_alone(): void
    {
        // That is something an employee submitted; editing one day of the sheet
        // must not silently rewrite it.
        [, $token] = $this->admin();
        $end = TenantClock::now($this->tenantId)->modify('+2 days')->format('Y-m-d');

        DB::table('leaves')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'date' => $this->date,
            'start_date' => $this->date,
            'end_date' => $end,
            'type' => 'annual',
            'status' => 'approved',
        ]);

        $this->set($token, ['status' => 'present', 'check_in_time' => '09:00'])->assertOk();

        $this->assertDatabaseHas('leaves', [
            'employee_id' => $this->employee->id,
            'start_date' => $this->date,
            'end_date' => $end,
        ]);
    }

    public function test_an_unknown_status_is_refused(): void
    {
        [, $token] = $this->admin();

        $this->set($token, ['status' => 'on_the_moon'])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'invalid_status');
    }

    public function test_an_unknown_leave_type_is_refused(): void
    {
        [, $token] = $this->admin();

        $this->set($token, ['status' => 'leave', 'leave_type' => 'sabbatical'])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'invalid_leave_type');
    }

    public function test_a_deduction_override_needs_a_value(): void
    {
        [, $token] = $this->admin();

        $this->set($token, ['status' => 'absent', 'deduction_mode' => 'days'])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'deduction_value_non_negative_number');
    }

    public function test_a_deduction_override_is_dropped_on_a_day_that_is_not_an_absence(): void
    {
        [, $token] = $this->admin();

        $this->set($token, [
            'status' => 'present',
            'check_in_time' => '09:00',
            'deduction_mode' => 'days',
            'deduction_value' => 2,
        ])->assertOk();

        $row = DB::table('attendance')->where('employee_id', $this->employee->id)
            ->where('date', $this->date)->first();

        $this->assertNotNull($row);
        $this->assertSame('auto', $row->deduction_mode);
        $this->assertNull($row->deduction_value);
    }

    public function test_touching_leave_needs_the_leave_permission_too(): void
    {
        // Moving a day into or out of leave changes somebody's balance.
        [$admin, $token] = $this->admin(['role' => 'attendance']);
        CustomRole::query()->create([
            'tenant_id' => $this->tenantId,
            'admin_id' => $admin->id,
            'name' => 'Attendance only',
            'permissions' => ['manage_attendance'],
        ]);

        $this->set($token, ['status' => 'leave'])
            ->assertForbidden()
            ->assertJsonPath('error_code', 'missing_permission');
    }

    public function test_an_attendance_only_manager_can_still_set_a_normal_day(): void
    {
        [$admin, $token] = $this->admin(['role' => 'attendance']);
        CustomRole::query()->create([
            'tenant_id' => $this->tenantId,
            'admin_id' => $admin->id,
            'name' => 'Attendance only',
            'permissions' => ['manage_attendance'],
        ]);

        $this->set($token, ['status' => 'present', 'check_in_time' => '09:00'])->assertOk();
    }

    public function test_an_employee_from_another_company_is_not_found(): void
    {
        [, $token] = $this->admin();

        $other = Employee::query()->where('tenant_id', '!=', $this->tenantId)->first();
        if ($other === null) {
            $this->markTestSkipped('needs a second company');
        }

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson(self::ENDPOINT, [
                'employee_id' => $other->id,
                'date' => $this->date,
                'status' => 'present',
            ])->assertNotFound();
    }

    public function test_the_change_is_audited_with_both_states(): void
    {
        [$admin, $token] = $this->admin();

        $this->set($token, ['status' => 'absent'])->assertOk();
        $this->set($token, ['status' => 'present', 'check_in_time' => '09:00'])->assertOk();

        $payload = DB::table('audit_log')
            ->where('admin_id', $admin->id)
            ->where('action', 'attendance.set_status')
            ->orderByDesc('id')
            ->value('payload');

        $this->assertIsString($payload);
        $decoded = json_decode($payload, true);
        $this->assertIsArray($decoded);
        $this->assertSame('absent', $decoded['from'] ?? null);
        $this->assertSame('present', $decoded['to'] ?? null);
    }
}
