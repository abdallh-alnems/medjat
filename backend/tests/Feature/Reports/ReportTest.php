<?php

declare(strict_types=1);

namespace Tests\Feature\Reports;

use App\Domain\Notifications\PushSender;
use App\Domain\Time\TenantClock;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * What a period looked like, per report.
 */
final class ReportTest extends TestCase
{
    use DatabaseTransactions;

    private const FROM = '2026-02-01';

    private const TO = '2026-02-28';

    private int $tenantId;

    private int $branchId;

    private int $employeeId;

    private string $adminToken;

    private string $viewerToken;

    private FakeFirebaseTokenVerifier $firebase;

    protected function setUp(): void
    {
        parent::setUp();
        TenantClock::flush();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));

        // The dump carries a whole company; these cases are about what this
        // test creates.
        DB::table('employees')->where('tenant_id', $this->tenantId)->update(['status' => 'terminated']);

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Report branch',
        ]);

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Reported on',
            'status' => 'active',
            'base_salary' => 3000,
            'branch_id' => $this->branchId,
        ]);

        $this->adminToken = $this->admin('general_manager');
        $this->viewerToken = $this->admin('viewer');
    }

    private function admin(string $role, ?int $branchId = null): string
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        DB::table('admins')->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Admin '.$role,
            'role' => $role,
            'branch_id' => $branchId,
            'is_active' => 1,
        ]);

        return $this->firebase->issue($uid);
    }

    private function asAdmin(): self
    {
        $this->withHeader('X-Firebase-Token', $this->adminToken);

        return $this;
    }

    /**
     * @param  array<string, mixed>  $extra
     */
    private function attendance(string $date, string $status, array $extra = []): void
    {
        DB::table('attendance')->insert($extra + [
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'branch_id' => $this->branchId,
            'date' => $date,
            'status' => $status,
        ]);
    }

    private function range(): string
    {
        return '?start_date='.self::FROM.'&end_date='.self::TO;
    }

    // ── Attendance ───────────────────────────────────────────────────────

    public function test_a_late_day_is_counted_as_late_not_present(): void
    {
        // Folding the two together would make a report where nobody is ever
        // late, which is the one thing these numbers exist to show.
        $this->attendance('2026-02-02', 'present', ['late_minutes' => 0, 'worked_minutes' => 480]);
        $this->attendance('2026-02-03', 'present', ['late_minutes' => 20, 'worked_minutes' => 460]);
        $this->attendance('2026-02-04', 'absent');

        $this->asAdmin()->getJson('/app/reports/attendance.php'.$this->range())
            ->assertOk()
            ->assertJsonPath('data.items.0.days_present', 1)
            ->assertJsonPath('data.items.0.days_late', 1)
            ->assertJsonPath('data.items.0.days_absent', 1)
            ->assertJsonPath('data.summary.total_present', 1)
            ->assertJsonPath('data.summary.total_late', 1);
    }

    public function test_somebody_with_no_attendance_at_all_still_appears(): void
    {
        // That is exactly who a manager opening this report is looking for.
        $this->asAdmin()->getJson('/app/reports/attendance.php'.$this->range())
            ->assertOk()
            ->assertJsonPath('data.items.0.employee_name', 'Reported on')
            ->assertJsonPath('data.items.0.days_recorded', 0);
    }

    public function test_a_malformed_date_is_refused(): void
    {
        $this->asAdmin()->getJson('/app/reports/attendance.php?start_date=february')
            ->assertStatus(422)->assertJsonPath('error_code', 'invalid_date');
    }

    // ── Overtime and lateness ────────────────────────────────────────────

    public function test_only_people_with_minutes_appear(): void
    {
        $quiet = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Always on time',
            'status' => 'active',
            'base_salary' => 1000,
            'branch_id' => $this->branchId,
        ]);
        DB::table('attendance')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $quiet,
            'branch_id' => $this->branchId,
            'date' => '2026-02-02',
            'status' => 'present',
            'late_minutes' => 0,
            'overtime_minutes' => 0,
        ]);
        $this->attendance('2026-02-02', 'present', ['late_minutes' => 30, 'overtime_minutes' => 60]);

        $items = $this->asAdmin()->getJson('/app/reports/overtime_late.php'.$this->range())
            ->assertOk()->json('data.items');

        $this->assertIsArray($items);
        $this->assertCount(1, $items);
        $this->assertIsArray($items[0]);
        $this->assertSame('Reported on', $items[0]['employee_name']);
    }

    public function test_absences_carry_no_minutes(): void
    {
        // An absence has none, so scoping to present days is what keeps the
        // totals honest.
        $this->attendance('2026-02-02', 'absent', ['late_minutes' => 999]);

        $items = $this->asAdmin()->getJson('/app/reports/overtime_late.php'.$this->range())
            ->assertOk()->json('data.items');

        $this->assertSame([], $items);
    }

    public function test_the_drill_down_shows_only_the_days_that_carry_minutes(): void
    {
        // A drill-down full of zeroes hides the ones that matter.
        $this->attendance('2026-02-02', 'present', ['late_minutes' => 30]);
        $this->attendance('2026-02-03', 'present', ['late_minutes' => 0, 'overtime_minutes' => 0]);

        $this->asAdmin()
            ->getJson('/app/reports/overtime_late.php'.$this->range().'&employee_id='.$this->employeeId)
            ->assertOk()
            ->assertJsonCount(1, 'data.days')
            ->assertJsonPath('data.days.0.late_minutes', 30);
    }

    public function test_the_sort_is_whitelisted(): void
    {
        // A client-supplied sort never reaches the SQL.
        $this->asAdmin()->getJson('/app/reports/overtime_late.php'.$this->range().'&sort=name;DROP')
            ->assertStatus(422)->assertJsonPath('error_code', 'invalid_sort');
    }

    public function test_a_backwards_window_is_refused(): void
    {
        $this->asAdmin()
            ->getJson('/app/reports/overtime_late.php?start_date=2026-03-01&end_date=2026-02-01')
            ->assertStatus(422)->assertJsonPath('error_code', 'start_date_before_end_date');
    }

    // ── Staff and leave ──────────────────────────────────────────────────

    public function test_the_staff_report_excludes_people_who_have_left(): void
    {
        // A headcount and a salary total are present-tense questions.
        $this->asAdmin()->getJson('/app/reports/employees.php')
            ->assertOk()
            ->assertJsonPath('data.summary.total_employees', 1)
            ->assertJsonPath('data.summary.total_salaries', '3000.00');
    }

    public function test_the_leave_report_counts_by_kind_and_state(): void
    {
        DB::table('leaves')->insert([
            [
                'tenant_id' => $this->tenantId, 'employee_id' => $this->employeeId,
                'date' => '2026-02-10', 'start_date' => '2026-02-10', 'end_date' => '2026-02-12',
                'type' => 'annual', 'status' => 'approved',
            ],
            [
                'tenant_id' => $this->tenantId, 'employee_id' => $this->employeeId,
                'date' => '2026-02-20', 'start_date' => '2026-02-20', 'end_date' => '2026-02-20',
                'type' => 'sick', 'status' => 'pending',
            ],
        ]);

        $this->asAdmin()->getJson('/app/reports/leaves.php'.$this->range())
            ->assertOk()
            ->assertJsonPath('data.summary.total_leaves', 2)
            ->assertJsonPath('data.summary.approved_count', 1)
            ->assertJsonPath('data.summary.pending_count', 1)
            ->assertJsonPath('data.summary.annual_count', 1)
            ->assertJsonPath('data.summary.sick_count', 1);
    }

    public function test_the_leave_report_can_be_narrowed_to_one_state(): void
    {
        DB::table('leaves')->insert([
            'tenant_id' => $this->tenantId, 'employee_id' => $this->employeeId,
            'date' => '2026-02-10', 'start_date' => '2026-02-10', 'end_date' => '2026-02-10',
            'type' => 'annual', 'status' => 'approved',
        ]);

        $this->asAdmin()->getJson('/app/reports/leaves.php'.$this->range().'&status=pending')
            ->assertOk()
            ->assertJsonPath('data.items', []);
    }

    // ── Payroll ──────────────────────────────────────────────────────────

    public function test_the_payroll_report_reads_the_saved_slips(): void
    {
        DB::table('payroll')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'branch_id' => $this->branchId,
            'month' => '2026-02',
            'base_salary' => 3000,
            'total_deductions' => 200,
            'total_bonuses' => 100,
            'net_salary' => 2900,
            'status' => 'approved',
        ]);

        $this->asAdmin()->getJson('/app/reports/payroll.php?month=2026-02')
            ->assertOk()
            ->assertJsonPath('data.summary.employee_count', 1)
            ->assertJsonPath('data.items.0.employee_name', 'Reported on')
            ->assertJsonPath('data.items.0.net_salary', '2900.00');
    }

    public function test_a_malformed_month_is_refused(): void
    {
        $this->asAdmin()->getJson('/app/reports/payroll.php?month=2026')
            ->assertStatus(422)->assertJsonPath('error_code', 'invalid_month');
    }

    // ── Scope ────────────────────────────────────────────────────────────

    public function test_an_administrator_pinned_to_a_branch_cannot_ask_about_another(): void
    {
        $otherBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Elsewhere',
        ]);
        $pinned = $this->admin('branch_manager', $this->branchId);

        $this->withHeader('X-Firebase-Token', $pinned)
            ->getJson('/app/reports/attendance.php'.$this->range().'&branch_id='.$otherBranch)
            ->assertForbidden();

        $this->withHeader('X-Firebase-Token', $pinned)
            ->getJson('/app/reports/attendance.php'.$this->range().'&branch_id='.$this->branchId)
            ->assertOk();
    }

    public function test_reports_are_closed_without_the_reports_permission(): void
    {
        $attendanceOnly = $this->admin('attendance');

        $this->withHeader('X-Firebase-Token', $attendanceOnly)
            ->getJson('/app/reports/attendance.php')->assertForbidden();

        // A viewer's whole job is reading these.
        $this->withHeader('X-Firebase-Token', $this->viewerToken)
            ->getJson('/app/reports/attendance.php')->assertOk();
    }
}
