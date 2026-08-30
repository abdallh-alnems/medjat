<?php

declare(strict_types=1);

namespace Tests\Feature\Leave;

use App\Domain\Notifications\PushSender;
use App\Services\Auth\FirebaseTokenVerifier;
use App\Services\Leave\YearRollover;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * Closing one leave year and opening the next.
 */
final class LeaveRolloverTest extends TestCase
{
    use DatabaseTransactions;

    private const FROM_YEAR = 2026;

    private int $tenantId;

    private int $employeeId;

    private string $adminToken;

    private YearRollover $rollover;

    protected function setUp(): void
    {
        parent::setUp();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->rollover = app(YearRollover::class);
        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));

        DB::table('tenants')->where('id', $this->tenantId)->update([
            'default_annual_leave_days' => 21,
            'apply_legal_seniority_entitlement' => 0,
            'leave_carryover_max_days' => null,
        ]);
        DB::table('leave_carryover_policies')->where('tenant_id', $this->tenantId)->delete();

        // The dump carries a whole company; a rollover walks all of them, and
        // these cases are about one person's arithmetic.
        DB::table('employees')->where('tenant_id', $this->tenantId)->update(['status' => 'terminated']);

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Rollover fixture',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2020-01-01',
        ]);

        $uid = 'uid-'.bin2hex(random_bytes(6));
        DB::table('admins')->insert([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Leave manager',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);
        $this->adminToken = $firebase->issue($uid);
    }

    /**
     * Uses up part of the year so a known number of days remains.
     */
    private function leaveRemaining(int $days): void
    {
        DB::table('employees')->where('id', $this->employeeId)->update(['annual_leave_days' => $days]);
    }

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function policy(array $overrides): void
    {
        DB::table('leave_carryover_policies')->insert($overrides + [
            'tenant_id' => $this->tenantId,
            'scope_type' => 'tenant',
            'scope_id' => null,
            'min_seniority_months' => 0,
            'carryover_enabled' => 1,
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function newYearBalance(): array
    {
        $row = DB::table('leave_year_balances')
            ->where('employee_id', $this->employeeId)->where('year', self::FROM_YEAR + 1)
            ->first();

        $this->assertNotNull($row);

        /** @var array<string, mixed> $columns */
        $columns = (array) $row;

        return $columns;
    }

    public function test_nothing_carries_when_no_policy_says_it_should(): void
    {
        $this->leaveRemaining(10);

        $result = $this->rollover->run($this->tenantId, self::FROM_YEAR);

        $this->assertSame(1, $result['processed']);
        $this->assertSame(0, $result['total_carried']);
        $this->assertSame(10, $result['total_dropped']);
    }

    public function test_a_cap_limits_what_carries_over(): void
    {
        $this->leaveRemaining(10);
        $this->policy(['carryover_max_days' => 4]);

        $result = $this->rollover->run($this->tenantId, self::FROM_YEAR);

        $this->assertSame(4, $result['total_carried']);
        $this->assertSame(6, $result['total_dropped']);
        $this->assertSame(4, Value::int($this->newYearBalance()['carried_over_days']));
    }

    public function test_an_uncapped_policy_carries_everything(): void
    {
        $this->leaveRemaining(10);
        $this->policy(['carryover_max_days' => null]);

        $this->assertSame(10, $this->rollover->run($this->tenantId, self::FROM_YEAR)['total_carried']);
    }

    public function test_the_excess_is_cashed_out_when_the_policy_says_so(): void
    {
        $this->leaveRemaining(10);
        $this->policy(['carryover_max_days' => 4, 'encash_excess' => 1]);

        $result = $this->rollover->run($this->tenantId, self::FROM_YEAR);

        $this->assertSame(4, $result['total_carried']);
        $this->assertSame(6, $result['total_encashed']);
        $this->assertSame(0, $result['total_dropped']);

        // Six days at 3000/30 a day.
        $this->assertDatabaseHas('leave_encashments', [
            'employee_id' => $this->employeeId,
            'source_year' => self::FROM_YEAR,
            'days' => 6,
            'amount' => '600.00',
            'status' => 'pending',
        ]);
    }

    public function test_a_statutory_floor_is_rescued_as_cash_rather_than_lost(): void
    {
        // The days the law protects survive one way or another, even under a
        // policy that would otherwise drop them.
        $this->leaveRemaining(10);
        $this->policy(['carryover_max_days' => 2, 'encash_excess' => 0, 'legal_min_carry_days' => 5]);

        $result = $this->rollover->run($this->tenantId, self::FROM_YEAR);

        $this->assertSame(2, $result['total_carried']);
        $this->assertSame(3, $result['total_encashed']);
        $this->assertSame(5, $result['total_dropped']);
    }

    public function test_the_floor_never_invents_days_the_employee_did_not_have(): void
    {
        $this->leaveRemaining(2);
        $this->policy(['carryover_max_days' => 0, 'legal_min_carry_days' => 15]);

        $result = $this->rollover->run($this->tenantId, self::FROM_YEAR);

        $this->assertSame(2, $result['total_encashed']);
    }

    public function test_the_new_year_records_the_entitlement_it_starts_with(): void
    {
        $this->leaveRemaining(30);
        $this->policy(['carryover_max_days' => 0]);

        $this->rollover->run($this->tenantId, self::FROM_YEAR);

        $this->assertSame(30, Value::int($this->newYearBalance()['entitlement_days']));
    }

    public function test_re_running_does_not_change_a_payout_already_made(): void
    {
        // Money somebody has been paid is not rewritten by an operator pressing
        // the button twice.
        $this->leaveRemaining(10);
        $this->policy(['carryover_max_days' => 0, 'encash_excess' => 1]);

        $this->rollover->run($this->tenantId, self::FROM_YEAR);
        DB::table('leave_encashments')
            ->where('employee_id', $this->employeeId)->where('source_year', self::FROM_YEAR)
            ->update(['status' => 'paid', 'days' => 10, 'amount' => 1000]);

        DB::table('employees')->where('id', $this->employeeId)->update(['annual_leave_days' => 4]);
        $this->rollover->run($this->tenantId, self::FROM_YEAR);

        $this->assertDatabaseHas('leave_encashments', [
            'employee_id' => $this->employeeId,
            'source_year' => self::FROM_YEAR,
            'days' => 10,
            'amount' => '1000.00',
            'status' => 'paid',
        ]);
    }

    public function test_re_running_refreshes_a_payout_still_pending(): void
    {
        $this->leaveRemaining(10);
        $this->policy(['carryover_max_days' => 0, 'encash_excess' => 1]);

        $this->rollover->run($this->tenantId, self::FROM_YEAR);
        DB::table('employees')->where('id', $this->employeeId)->update(['annual_leave_days' => 4]);
        $this->rollover->run($this->tenantId, self::FROM_YEAR);

        $this->assertDatabaseHas('leave_encashments', [
            'employee_id' => $this->employeeId,
            'source_year' => self::FROM_YEAR,
            'days' => 4,
            'status' => 'pending',
        ]);
    }

    public function test_terminated_staff_are_left_out(): void
    {
        $this->leaveRemaining(10);
        $this->policy(['carryover_max_days' => 5]);
        DB::table('employees')->where('id', $this->employeeId)->update(['status' => 'terminated']);

        $this->assertSame(0, $this->rollover->run($this->tenantId, self::FROM_YEAR)['processed']);
    }

    // ── Over HTTP ────────────────────────────────────────────────────────

    public function test_the_rollover_endpoint_reports_what_it_did_and_leaves_a_trail(): void
    {
        $this->leaveRemaining(10);
        $this->policy(['carryover_max_days' => 4]);

        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->postJson('/app/leaves/rollover.php', ['from_year' => self::FROM_YEAR])
            ->assertOk()
            ->assertJsonPath('data.to_year', self::FROM_YEAR + 1)
            ->assertJsonPath('data.total_carried', 4);

        $this->assertDatabaseHas('audit_log', [
            'tenant_id' => $this->tenantId,
            'action' => 'leave.rollover',
        ]);
    }

    public function test_a_nonsense_year_is_refused(): void
    {
        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->postJson('/app/leaves/rollover.php', ['from_year' => 99])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'from_year_valid_year');
    }

    public function test_carryover_policies_are_saved_read_back_and_removed(): void
    {
        $branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Policy branch',
        ]);

        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->postJson('/app/leaves/carryover_policy_save.php', [
                'scope_type' => 'branch',
                'scope_id' => $branchId,
                'carryover_enabled' => true,
                'carryover_max_days' => 7,
                'encash_excess' => true,
            ])->assertOk();

        $listed = $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/app/leaves/carryover_policies_list.php')
            ->assertOk()
            ->json('data.policies');

        $this->assertIsArray($listed);
        $saved = null;
        foreach ($listed as $policy) {
            if (is_array($policy) && Value::int($policy['scope_id'] ?? null) === $branchId) {
                $saved = $policy;
            }
        }

        $this->assertIsArray($saved);
        $this->assertSame(7, Value::int($saved['carryover_max_days']));

        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->postJson('/app/leaves/carryover_policy_delete.php', ['id' => Value::int($saved['id'])])
            ->assertOk();

        $this->assertDatabaseMissing('leave_carryover_policies', ['id' => Value::int($saved['id'])]);
    }

    public function test_the_company_wide_policy_is_not_editable_from_here(): void
    {
        // It belongs to the leave settings screen; two ways to write one row is
        // how the two screens end up disagreeing.
        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->postJson('/app/leaves/carryover_policy_save.php', [
                'scope_type' => 'tenant',
                'scope_id' => 1,
                'carryover_enabled' => true,
            ])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'scope_type_branch_category_employee');
    }

    public function test_an_out_of_range_cap_is_refused(): void
    {
        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->postJson('/app/leaves/carryover_policy_save.php', [
                'scope_type' => 'employee',
                'scope_id' => $this->employeeId,
                'carryover_enabled' => true,
                'carryover_max_days' => 400,
            ])
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'carryover_max_days_between_0');
    }

    public function test_pending_payouts_are_listed_with_the_names_behind_them(): void
    {
        DB::table('leave_encashments')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'source_year' => 2025,
            'days' => 5,
            'daily_rate' => 100,
            'amount' => 500,
            'status' => 'pending',
        ]);

        $this->withHeader('X-Firebase-Token', $this->adminToken)
            ->getJson('/app/leaves/encashments_list.php?status=pending')
            ->assertOk()
            ->assertJsonPath('data.encashments.0.employee_name', 'Rollover fixture')
            ->assertJsonPath('data.encashments.0.days', 5);
    }
}
