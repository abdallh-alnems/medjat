<?php

declare(strict_types=1);

namespace Tests\Feature\Schedule;

use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Modules\Schedule\Domain\WeeklyRoster;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\CreatesFixtures;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * The rotating-shift grid.
 */
final class RosterTest extends TestCase
{
    use CreatesFixtures;
    use DatabaseTransactions;

    /** A Saturday. */
    private const WEEK = '2026-05-02';

    private const NEXT_WEEK = '2026-05-09';

    private int $tenantId;

    private int $branchId;

    private int $otherBranchId;

    private int $employeeId;

    private int $elsewhere;

    private int $shiftId;

    private FakeFirebaseTokenVerifier $firebase;

    private string $adminToken;

    protected function setUp(): void
    {
        parent::setUp();

        $this->firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $this->firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = $this->createTenant();
        DB::table('tenants')->where('id', $this->tenantId)->update(['week_start_day' => 6]);

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId, 'name' => 'Roster branch', 'is_active' => 1,
        ]);
        $this->otherBranchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId, 'name' => 'Other branch', 'is_active' => 1,
        ]);

        $this->employeeId = $this->employee($this->branchId);
        $this->elsewhere = $this->employee($this->otherBranchId);

        $this->shiftId = (int) DB::table('shifts')->insertGetId([
            'tenant_id' => $this->tenantId,
            'branch_id' => $this->branchId,
            'name' => 'Morning',
            'start_time' => '09:00:00',
            'end_time' => '17:00:00',
        ]);

        $this->adminToken = $this->admin('general_manager');
    }

    private function employee(int $branchId, string $status = 'active'): int
    {
        return (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'branch_id' => $branchId,
            'name' => 'Rostered '.bin2hex(random_bytes(3)),
            'status' => $status,
            'base_salary' => 3000,
            'hire_date' => '2021-01-01',
        ]);
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

    /**
     * @param  array<string, mixed>  $payload
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function send(string $path, array $payload = [], ?string $token = null): TestResponse
    {
        return $this->withHeader('X-Firebase-Token', $token ?? $this->adminToken)->postJson($path, $payload);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function assign(array $overrides = [], ?string $token = null): TestResponse
    {
        return $this->send('/v1/schedule/assign', $overrides + [
            'employee_ids' => [$this->employeeId],
            'dates' => [self::WEEK, '2026-05-03'],
            'shift_id' => $this->shiftId,
        ], $token);
    }

    public function test_assigning_writes_one_cell_per_employee_per_day(): void
    {
        $this->assign()->assertOk()->assertJsonPath('data.updated', 2);

        $this->assertSame(2, DB::table('employee_shift_schedule')
            ->where('employee_id', $this->employeeId)->count());
    }

    public function test_a_new_cell_starts_as_a_draft(): void
    {
        $this->assign()->assertOk();

        // People plan their lives around this grid; a change nobody confirmed
        // must not become the thing they are judged against.
        $this->assertDatabaseHas('employee_shift_schedule', [
            'employee_id' => $this->employeeId, 'work_date' => self::WEEK, 'status' => 'draft',
        ]);
    }

    public function test_editing_a_published_cell_knocks_it_back_to_draft(): void
    {
        $this->assign()->assertOk();
        $this->send('/v1/schedule/publish', ['week_start' => self::WEEK])->assertOk();

        $this->assign(['shift_id' => null])->assertOk();

        $this->assertDatabaseHas('employee_shift_schedule', [
            'employee_id' => $this->employeeId, 'work_date' => self::WEEK, 'status' => 'draft',
        ]);
    }

    public function test_omitting_the_shift_records_a_rest_day(): void
    {
        $this->send('/v1/schedule/assign', [
            'employee_ids' => [$this->employeeId],
            'dates' => [self::WEEK],
            'shift_id' => null,
        ])->assertOk();

        // A rest day is a decision, distinct from an empty cell where nothing
        // was decided.
        $this->assertDatabaseHas('employee_shift_schedule', [
            'employee_id' => $this->employeeId, 'work_date' => self::WEEK, 'shift_id' => null,
        ]);
    }

    public function test_assigning_the_same_cell_twice_replaces_it(): void
    {
        $this->assign()->assertOk();
        $this->assign(['shift_id' => null])->assertOk();

        $this->assertSame(2, DB::table('employee_shift_schedule')
            ->where('employee_id', $this->employeeId)->count());
        $this->assertNull(DB::table('employee_shift_schedule')
            ->where('employee_id', $this->employeeId)->where('work_date', self::WEEK)->value('shift_id'));
    }

    public function test_an_unknown_shift_is_refused(): void
    {
        $this->assign(['shift_id' => 99999999])->assertStatus(404);
    }

    public function test_a_malformed_date_is_refused(): void
    {
        $this->assign(['dates' => ['02-05-2026']])->assertStatus(422);

        $this->assertSame(0, DB::table('employee_shift_schedule')
            ->where('employee_id', $this->employeeId)->count());
    }

    public function test_an_empty_selection_is_refused(): void
    {
        $this->assign(['employee_ids' => []])->assertStatus(422);
        $this->assign(['dates' => []])->assertStatus(422);
    }

    public function test_clearing_removes_the_cell_entirely(): void
    {
        $this->assign()->assertOk();

        $this->send('/v1/schedule/clear', [
            'employee_id' => $this->employeeId, 'work_date' => self::WEEK,
        ])->assertOk();

        // Gone, not marked as rest: attendance falls back to the standing shift.
        $this->assertDatabaseMissing('employee_shift_schedule', [
            'employee_id' => $this->employeeId, 'work_date' => self::WEEK,
        ]);
        $this->assertDatabaseHas('employee_shift_schedule', [
            'employee_id' => $this->employeeId, 'work_date' => '2026-05-03',
        ]);
    }

    public function test_publishing_makes_the_week_the_attendance_source(): void
    {
        $this->assign()->assertOk();

        $this->send('/v1/schedule/publish', ['week_start' => self::WEEK])
            ->assertOk()
            ->assertJsonPath('data.published', 2);

        $this->assertSame(2, DB::table('employee_shift_schedule')
            ->where('employee_id', $this->employeeId)->where('status', 'published')->count());
    }

    public function test_publishing_leaves_the_next_week_alone(): void
    {
        $this->assign(['dates' => [self::WEEK, self::NEXT_WEEK]])->assertOk();

        $this->send('/v1/schedule/publish', ['week_start' => self::WEEK])
            ->assertOk()
            ->assertJsonPath('data.published', 1);

        $this->assertDatabaseHas('employee_shift_schedule', [
            'employee_id' => $this->employeeId, 'work_date' => self::NEXT_WEEK, 'status' => 'draft',
        ]);
    }

    public function test_publishing_one_branch_leaves_another_in_draft(): void
    {
        $this->send('/v1/schedule/assign', [
            'employee_ids' => [$this->employeeId, $this->elsewhere],
            'dates' => [self::WEEK],
            'shift_id' => $this->shiftId,
        ])->assertOk();

        $this->send('/v1/schedule/publish', [
            'week_start' => self::WEEK, 'branch_id' => $this->branchId,
        ])->assertOk()->assertJsonPath('data.published', 1);

        $this->assertDatabaseHas('employee_shift_schedule', [
            'employee_id' => $this->elsewhere, 'status' => 'draft',
        ]);
    }

    public function test_copying_a_week_preserves_the_shape_of_it(): void
    {
        $this->assign(['dates' => ['2026-05-04']])->assertOk();

        $this->send('/v1/schedule/copy-week', [
            'from_week_start' => self::WEEK,
            'to_week_start' => self::NEXT_WEEK,
        ])->assertOk()->assertJsonPath('data.copied', 1);

        // Whoever was on Monday lands on Monday.
        $this->assertDatabaseHas('employee_shift_schedule', [
            'employee_id' => $this->employeeId,
            'work_date' => '2026-05-11',
            'shift_id' => $this->shiftId,
        ]);
    }

    public function test_a_copied_week_arrives_as_a_draft(): void
    {
        $this->assign(['dates' => [self::WEEK]])->assertOk();
        $this->send('/v1/schedule/publish', ['week_start' => self::WEEK])->assertOk();

        $this->send('/v1/schedule/copy-week', [
            'from_week_start' => self::WEEK, 'to_week_start' => self::NEXT_WEEK,
        ])->assertOk();

        $this->assertDatabaseHas('employee_shift_schedule', [
            'employee_id' => $this->employeeId, 'work_date' => self::NEXT_WEEK, 'status' => 'draft',
        ]);
    }

    public function test_copying_an_empty_week_copies_nothing(): void
    {
        $this->send('/v1/schedule/copy-week', [
            'from_week_start' => self::WEEK, 'to_week_start' => self::NEXT_WEEK,
        ])->assertOk()->assertJsonPath('data.copied', 0);
    }

    public function test_a_malformed_week_start_is_refused(): void
    {
        $this->send('/v1/schedule/publish', ['week_start' => 'next week'])->assertStatus(422);
        $this->send('/v1/schedule/copy-week', [
            'from_week_start' => self::WEEK, 'to_week_start' => 'soon',
        ])->assertStatus(422);
    }

    public function test_the_grid_returns_the_week_its_days_and_its_cells(): void
    {
        $this->assign()->assertOk();

        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/v1/schedule/week?week_start='.self::WEEK)
            ->assertOk()
            ->assertJsonPath('data.week_start', self::WEEK)
            ->assertJsonPath('data.week_end', '2026-05-08')
            ->assertJsonPath('data.week_start_day', 6)
            ->assertJsonCount(7, 'data.days')
            ->assertJsonCount(2, 'data.cells');
    }

    public function test_any_day_of_the_week_snaps_back_to_its_start(): void
    {
        // The client may send whichever day the user is looking at; the grid
        // has to line up regardless.
        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/v1/schedule/week?week_start=2026-05-06')
            ->assertOk()
            ->assertJsonPath('data.week_start', self::WEEK);
    }

    public function test_the_week_starts_on_the_day_the_company_chose(): void
    {
        // Monday, not Saturday.
        DB::table('tenants')->where('id', $this->tenantId)->update(['week_start_day' => 1]);

        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/v1/schedule/week?week_start=2026-05-06')
            ->assertOk()
            ->assertJsonPath('data.week_start', '2026-05-04')
            ->assertJsonPath('data.week_start_day', 1);
    }

    public function test_the_grid_can_be_narrowed_to_one_branch(): void
    {
        $this->send('/v1/schedule/assign', [
            'employee_ids' => [$this->employeeId, $this->elsewhere],
            'dates' => [self::WEEK],
            'shift_id' => $this->shiftId,
        ])->assertOk();

        $response = $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/v1/schedule/week?week_start='.self::WEEK.'&branch_id='.$this->branchId)
            ->assertOk()
            ->assertJsonCount(1, 'data.cells');

        $this->assertSame($this->employeeId, Value::int($response->json('data.cells.0.employee_id')));
    }

    public function test_terminated_staff_are_left_off_the_grid(): void
    {
        $leaver = $this->employee($this->branchId, 'terminated');

        $response = $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/v1/schedule/week?week_start='.self::WEEK.'&branch_id='.$this->branchId)
            ->assertOk();

        /** @var list<array<string, mixed>> $employees */
        $employees = (array) $response->json('data.employees');
        $ids = array_map(static fn (array $row): int => Value::int($row['id'] ?? null), $employees);

        $this->assertNotContains($leaver, $ids);
        $this->assertContains($this->employeeId, $ids);
    }

    public function test_a_viewer_cannot_open_or_change_the_roster(): void
    {
        $token = $this->admin('viewer');

        $this->withHeader('X-Firebase-Token', $token)
            ->getJson('/v1/schedule/week?week_start='.self::WEEK)
            ->assertStatus(403);

        $this->assign([], $token)->assertStatus(403);
    }

    public function test_a_week_is_snapped_by_the_companys_chosen_day(): void
    {
        // Saturday-start: Wednesday belongs to the week that began three days
        // earlier.
        $this->assertSame('2026-05-02', WeeklyRoster::snapToWeekStart('2026-05-06', 6));
        // Monday-start: the same Wednesday belongs to a week that began Monday.
        $this->assertSame('2026-05-04', WeeklyRoster::snapToWeekStart('2026-05-06', 1));
        // A day that is itself the start stays put.
        $this->assertSame('2026-05-02', WeeklyRoster::snapToWeekStart('2026-05-02', 6));
    }
}
