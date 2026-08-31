<?php

declare(strict_types=1);

namespace Tests\Feature\Attendance;

use App\Models\Admin;
use App\Models\Employee;
use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\TestCase;

/**
 * Attendance recorded for an employee by an administrator, and the note on a
 * day.
 *
 * This is the one action in the module with no evidence behind it, which is why
 * it is gated twice and why overwriting a real punch is refused.
 */
final class ManualAttendanceTest extends TestCase
{
    use DatabaseTransactions;

    private Employee $employee;

    private int $branchId;

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

        $this->branchId = (int) $this->employee->branch_id;
        $this->tenantId = $this->employee->tenant_id;
        $this->date = TenantClock::now($this->tenantId)->modify('-6 days')->format('Y-m-d');

        DB::table('tenants')->where('id', $this->tenantId)->update([
            'attendance_methods' => json_encode(['gps_only', 'manual']),
            'manual_attendance_admin_ids' => null,
        ]);
        DB::table('branches')->where('id', $this->branchId)->update(['attendance_methods' => null]);
        Employee::query()->whereKey($this->employee->id)
            ->update(['work_start_time' => '09:00:00', 'work_end_time' => '17:00:00']);

        DB::table('attendance')->where('employee_id', $this->employee->id)->where('date', $this->date)->delete();
    }

    /** @return array{Admin, string} */
    private function admin(): array
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        $id = Admin::query()->insertGetId([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Manager',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);

        return [Admin::query()->findOrFail($id), $this->firebase->issue($uid)];
    }

    /**
     * @param  array<string, mixed>  $body
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function record(string $token, array $body): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/manual', array_merge([
                'employee_id' => $this->employee->id,
                'branch_id' => $this->branchId,
                'date' => $this->date,
            ], $body));
    }

    public function test_a_whole_day_is_recorded_with_its_derived_minutes(): void
    {
        [, $token] = $this->admin();

        $this->record($token, ['check_in_time' => '09:15:00', 'check_out_time' => '17:45:00'])->assertOk();

        $row = DB::table('attendance')->where('employee_id', $this->employee->id)
            ->where('date', $this->date)->first();

        $this->assertNotNull($row);
        $this->assertSame(15, Value::int($row->late_minutes));
        $this->assertSame(45, Value::int($row->overtime_minutes));
        $this->assertSame(510, Value::int($row->worked_minutes));
        $this->assertSame('manual', $row->check_in_method);
    }

    public function test_a_check_in_alone_will_not_overwrite_a_real_punch(): void
    {
        // That would erase a real arrival behind the employee's back.
        [, $token] = $this->admin();
        DB::table('attendance')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'branch_id' => $this->branchId,
            'date' => $this->date,
            'check_in_time' => '08:55:00',
            'check_in_method' => 'gps_only',
            'status' => 'present',
        ]);

        $this->record($token, ['check_in_time' => '10:00:00'])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'already_checked_in');

        $this->assertSame('08:55:00', DB::table('attendance')
            ->where('employee_id', $this->employee->id)->where('date', $this->date)->value('check_in_time'));
    }

    public function test_a_whole_day_replaces_what_was_there(): void
    {
        // Different from a check-in alone: entering the whole day is a
        // deliberate correction of the record.
        [, $token] = $this->admin();
        DB::table('attendance')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'branch_id' => $this->branchId,
            'date' => $this->date,
            'check_in_time' => '08:55:00',
            'status' => 'present',
        ]);

        $this->record($token, ['check_in_time' => '09:00:00', 'check_out_time' => '17:00:00'])->assertOk();

        $this->assertSame('09:00:00', DB::table('attendance')
            ->where('employee_id', $this->employee->id)->where('date', $this->date)->value('check_in_time'));
    }

    public function test_a_check_out_alone_needs_an_arrival_to_attach_to(): void
    {
        [, $token] = $this->admin();

        $this->record($token, ['check_out_time' => '17:00:00'])
            ->assertNotFound()
            ->assertJsonPath('error_code', 'no_check_in_record');
    }

    public function test_a_check_out_alone_closes_an_open_day(): void
    {
        [, $token] = $this->admin();
        DB::table('attendance')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'branch_id' => $this->branchId,
            'date' => $this->date,
            'check_in_time' => '09:00:00',
            'status' => 'present',
        ]);

        $this->record($token, ['check_out_time' => '18:00:00'])->assertOk();

        $row = DB::table('attendance')->where('employee_id', $this->employee->id)
            ->where('date', $this->date)->first();

        $this->assertNotNull($row);
        $this->assertSame('18:00:00', $row->check_out_time);
        $this->assertSame(540, Value::int($row->worked_minutes));
        $this->assertSame(60, Value::int($row->overtime_minutes));
    }

    public function test_neither_time_is_refused(): void
    {
        [, $token] = $this->admin();

        $this->record($token, [])
            ->assertStatus(400)
            ->assertJsonPath('error_code', 'either_check_time_check_out');
    }

    public function test_a_company_with_manual_disabled_is_refused(): void
    {
        [, $token] = $this->admin();
        DB::table('tenants')->where('id', $this->tenantId)
            ->update(['attendance_methods' => json_encode(['gps_only'])]);

        $this->record($token, ['check_in_time' => '09:00:00'])
            ->assertForbidden()
            ->assertJsonPath('error_code', 'manual_disabled');
    }

    public function test_an_admin_not_on_the_named_list_is_refused(): void
    {
        // Recording someone else's hours has no evidence behind it, so who may
        // do it is worth narrowing.
        [, $token] = $this->admin();
        DB::table('tenants')->where('id', $this->tenantId)
            ->update(['manual_attendance_admin_ids' => json_encode([999999])]);

        $this->record($token, ['check_in_time' => '09:00:00'])
            ->assertForbidden()
            ->assertJsonPath('error_code', 'manual_not_authorized');
    }

    public function test_a_branch_can_opt_out_even_when_the_company_allows_it(): void
    {
        [, $token] = $this->admin();
        DB::table('branches')->where('id', $this->branchId)
            ->update(['attendance_methods' => json_encode(['gps_only'])]);

        $this->record($token, ['check_in_time' => '09:00:00'])
            ->assertForbidden()
            ->assertJsonPath('error_code', 'manual_disabled_branch');
    }

    public function test_a_note_can_be_attached_while_recording(): void
    {
        [, $token] = $this->admin();

        $this->record($token, ['check_in_time' => '09:00:00', 'notes' => 'Covered the late shift'])->assertOk();

        $this->assertSame('Covered the late shift', DB::table('attendance')
            ->where('employee_id', $this->employee->id)->where('date', $this->date)->value('notes'));
    }

    // ── Notes ────────────────────────────────────────────────────────────

    public function test_a_note_is_addressable_by_attendance_id(): void
    {
        [, $token] = $this->admin();
        $id = DB::table('attendance')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'branch_id' => $this->branchId,
            'date' => $this->date,
            'status' => 'present',
        ]);

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/note', ['attendance_id' => $id, 'note' => 'Checked with HR'])
            ->assertOk()
            ->assertJsonPath('data.note', 'Checked with HR');
    }

    public function test_a_note_is_addressable_by_employee_and_date(): void
    {
        [, $token] = $this->admin();
        DB::table('attendance')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'branch_id' => $this->branchId,
            'date' => $this->date,
            'status' => 'present',
        ]);

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/note', [
                'employee_id' => $this->employee->id,
                'date' => $this->date,
                'note' => 'By date',
            ])->assertOk();

        $this->assertSame('By date', DB::table('attendance')
            ->where('employee_id', $this->employee->id)->where('date', $this->date)->value('notes'));
    }

    public function test_saving_the_same_note_twice_still_succeeds(): void
    {
        // MySQL reports zero affected rows when the value is unchanged, which
        // would otherwise make a successful no-op look like a missing record.
        [, $token] = $this->admin();
        $id = DB::table('attendance')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'branch_id' => $this->branchId,
            'date' => $this->date,
            'status' => 'present',
            'notes' => 'Same',
        ]);

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/note', ['attendance_id' => $id, 'note' => 'Same'])
            ->assertOk();
    }

    public function test_an_empty_note_clears_it(): void
    {
        [, $token] = $this->admin();
        $id = DB::table('attendance')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employee->id,
            'branch_id' => $this->branchId,
            'date' => $this->date,
            'status' => 'present',
            'notes' => 'Something',
        ]);

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/note', ['attendance_id' => $id, 'note' => '   '])
            ->assertOk()
            ->assertJsonPath('data.note', null);

        $this->assertNull(DB::table('attendance')->where('id', $id)->value('notes'));
    }

    public function test_a_note_on_a_row_that_does_not_exist_is_a_404(): void
    {
        [, $token] = $this->admin();

        $this->withHeader('X-Firebase-Token', $token)
            ->postJson('/v1/attendance/note', ['attendance_id' => 999999, 'note' => 'x'])
            ->assertNotFound()
            ->assertJsonPath('error_code', 'attendance_record_not_found');
    }
}
