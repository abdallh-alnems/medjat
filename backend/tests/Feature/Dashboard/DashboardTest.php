<?php

declare(strict_types=1);

namespace Tests\Feature\Dashboard;

use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Where everybody stands today.
 */
final class DashboardTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $branchId;

    private string $today;

    private FakeFirebaseTokenVerifier $firebase;

    private string $adminToken;

    protected function setUp(): void
    {
        parent::setUp();
        TenantClock::flush();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));
        $this->today = TenantClock::date($this->tenantId);

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId, 'name' => 'Board branch', 'is_active' => 1,
        ]);

        // Everybody else's fixtures would otherwise land on today's board.
        DB::table('employees')->where('tenant_id', $this->tenantId)
            ->where('status', 'active')->update(['status' => 'suspended']);

        $this->adminToken = $this->admin('general_manager');
    }

    private function admin(string $role): string
    {
        $uid = 'uid-'.bin2hex(random_bytes(6));
        DB::table('admins')->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Admin '.$role,
            'role' => $role,
            'is_active' => 1,
        ]);

        return $this->firebase->issue($uid);
    }

    private function employee(string $name, ?string $start = '09:00:00', ?string $end = '17:00:00'): int
    {
        return (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'name' => $name,
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
            'work_start_time' => $start,
            'work_end_time' => $end,
        ]);
    }

    private function shift(int $days): string
    {
        return TenantClock::now($this->tenantId)
            ->modify(($days >= 0 ? '+' : '-').abs($days).' days')
            ->format('Y-m-d');
    }

    /**
     * @param  array<string, mixed>  $fields
     */
    private function attendance(int $employeeId, array $fields): void
    {
        DB::table('attendance')->insert($fields + [
            'tenant_id' => $this->tenantId,
            'employee_id' => $employeeId,
            'date' => $this->today,
        ]);
    }

    /**
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function board(?string $token = null): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $token ?? $this->adminToken)
            ->getJson('/v1/dashboard/live-attendance');
    }

    /**
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function overview(?string $token = null): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $token ?? $this->adminToken)
            ->getJson('/v1/dashboard/overview');
    }

    public function test_somebody_who_has_not_punched_still_appears(): void
    {
        // A board that lists only people who punched cannot show a no-show.
        $this->employee('Never arrived');

        $this->board()->assertOk()->assertJsonPath('data.summary.total', 1);
    }

    public function test_checked_in_reads_as_in_and_checked_out_as_out(): void
    {
        $in = $this->employee('Still here');
        $out = $this->employee('Gone home');

        $this->attendance($in, ['check_in_time' => '09:00:00', 'status' => 'present']);
        $this->attendance($out, [
            'check_in_time' => '09:00:00', 'check_out_time' => '17:00:00', 'status' => 'present',
        ]);

        $this->board()
            ->assertOk()
            ->assertJsonPath('data.summary.in', 1)
            ->assertJsonPath('data.summary.out', 1);
    }

    public function test_a_confirmed_absence_and_a_no_show_are_counted_apart(): void
    {
        // Midday, inside the fixture's 09:00–17:00 shift. Before it starts a
        // no-show is correctly 'pre_shift' instead, which is a different
        // distinction and has its own test below.
        $this->travelTo(TenantClock::now($this->tenantId)->setTime(12, 0));

        // Otherwise the two overlap and the same person is counted twice.
        $absent = $this->employee('Marked absent');
        $this->employee('No record yet');

        $this->attendance($absent, ['status' => 'absent']);

        $this->board()
            ->assertOk()
            ->assertJsonPath('data.summary.absent', 1)
            ->assertJsonPath('data.summary.not_in', 1);
    }

    public function test_a_night_shift_before_its_start_is_not_a_no_show(): void
    {
        // 23:00–07:00. Whatever hour the suite runs, a shift that has not begun
        // must not put a third of the workforce on the exceptions list.
        $this->employee('Night worker', '23:00:00', '07:00:00');

        $response = $this->board()->assertOk();

        $now = TenantClock::now($this->tenantId)->format('H:i:s');
        $expectedPreShift = $now > '07:00:00' && $now < '23:00:00' ? 1 : 0;

        $this->assertSame($expectedPreShift, Value::int($response->json('data.summary.pre_shift')));
    }

    public function test_every_day_of_a_multi_day_leave_counts_as_leave(): void
    {
        // The leave row's `date` column holds only the start, so matching on it
        // recognised day one and let the rest fall through to "not arrived" —
        // and then to an absence, and then to a deduction.
        $employee = $this->employee('On a week off');

        DB::table('leaves')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $employee,
            'date' => $this->shift(-3),
            'start_date' => $this->shift(-3),
            'end_date' => $this->shift(3),
            'type' => 'annual',
            'status' => 'approved',
        ]);

        $this->board()
            ->assertOk()
            ->assertJsonPath('data.summary.leave', 1)
            ->assertJsonPath('data.summary.not_in', 0);
    }

    public function test_a_holiday_reads_as_leave_with_its_reason(): void
    {
        $employee = $this->employee('Public holiday');
        $this->attendance($employee, ['status' => 'holiday', 'notes' => 'عيد الفطر']);

        $this->board()
            ->assertOk()
            ->assertJsonPath('data.summary.leave', 1)
            ->assertJsonPath('data.employees.0.leave_reason', 'عيد الفطر');
    }

    public function test_lateness_is_only_counted_for_people_who_actually_came(): void
    {
        $present = $this->employee('Late but here');
        $this->attendance($present, [
            'check_in_time' => '09:30:00', 'status' => 'present', 'late_minutes' => 30,
        ]);

        $this->board()
            ->assertOk()
            ->assertJsonPath('data.summary.late', 1)
            ->assertJsonPath('data.employees.0.is_late', true);
    }

    public function test_the_board_can_be_narrowed_to_a_branch(): void
    {
        $otherBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId, 'name' => 'Elsewhere', 'is_active' => 1,
        ]);
        $this->employee('Here');
        DB::table('employees')->insert([
            'tenant_id' => $this->tenantId,
            'branch_id' => $otherBranch,
            'name' => 'There',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
        ]);

        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/v1/dashboard/live-attendance?branch_id='.$this->branchId)
            ->assertOk()
            ->assertJsonPath('data.summary.total', 1);
    }

    public function test_the_overview_reports_the_headcount_and_the_scope_apart(): void
    {
        $this->employee('One');
        $this->employee('Two');

        // The unfiltered headcount drives the first-run empty state, which a
        // branch filter must not make look like a company with no employees.
        $response = $this->overview()->assertOk();

        $this->assertGreaterThanOrEqual(2, Value::int($response->json('data.total_employees')));
        $this->assertSame(2, Value::int($response->json('data.active_in_scope')));
    }

    public function test_the_overview_reports_the_queues_waiting_on_somebody(): void
    {
        $employee = $this->employee('Requester');
        $before = Value::int($this->overview()->json('data.pending_leaves'));

        DB::table('leaves')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $employee,
            'date' => '2026-09-01',
            'start_date' => '2026-09-01',
            'end_date' => '2026-09-02',
            'type' => 'annual',
            'status' => 'pending',
        ]);

        $this->overview()->assertOk()->assertJsonPath('data.pending_leaves', $before + 1);
    }

    public function test_the_overview_aggregates_by_branch(): void
    {
        $present = $this->employee('Attended');
        $this->employee('Did not');
        $this->attendance($present, ['check_in_time' => '09:00:00', 'status' => 'present']);

        $response = $this->overview()->assertOk();

        /** @var list<array<string, mixed>> $stats */
        $stats = (array) $response->json('data.branch_stats');
        $this->assertCount(1, $stats);
        $this->assertSame(2, Value::int($stats[0]['total_employees'] ?? null));
        $this->assertSame(1, Value::int($stats[0]['present'] ?? null));
        $this->assertSame(50.0, Value::float($stats[0]['attendance_rate'] ?? null));
    }

    public function test_the_overview_reports_the_current_month(): void
    {
        $this->overview()
            ->assertOk()
            ->assertJsonPath('data.current_month', substr($this->today, 0, 7))
            ->assertJsonStructure(['data' => ['payroll_summary' => ['total_net']]]);
    }

    public function test_a_viewer_can_open_the_overview_but_not_the_live_board(): void
    {
        // The overview is the screen the app opens on. The live board is a
        // report.
        $token = $this->admin('attendance');

        $this->overview($token)->assertOk();
        $this->board($token)->assertStatus(403);
    }
}
