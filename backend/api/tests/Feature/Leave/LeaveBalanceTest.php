<?php

declare(strict_types=1);

namespace Tests\Feature\Leave;

use App\Modules\Leave\Domain\CarryoverPolicy;
use App\Modules\Leave\Domain\LeaveBalanceCalculator;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * How much annual leave somebody has left, and what happens to what they
 * did not take.
 */
final class LeaveBalanceTest extends TestCase
{
    use DatabaseTransactions;

    private int $tenantId;

    private int $employeeId;

    private LeaveBalanceCalculator $balances;

    protected function setUp(): void
    {
        parent::setUp();

        $this->balances = app(LeaveBalanceCalculator::class);
        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));

        DB::table('tenants')->where('id', $this->tenantId)->update([
            'default_annual_leave_days' => 21,
            'apply_legal_seniority_entitlement' => 0,
            'leave_carryover_max_days' => null,
        ]);
        DB::table('leave_carryover_policies')->where('tenant_id', $this->tenantId)->delete();

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Leave fixture',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2020-01-01',
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function balance(int $year = 2026): array
    {
        return $this->balances->forYear($this->employeeId, $this->tenantId, $year);
    }

    private function leave(string $start, string $end, string $status = 'approved', string $type = 'annual'): void
    {
        DB::table('leaves')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'date' => $start,
            'start_date' => $start,
            'end_date' => $end,
            'type' => $type,
            'status' => $status,
        ]);
    }

    // ── Entitlement ──────────────────────────────────────────────────────

    public function test_the_company_default_applies_when_the_employee_has_no_figure_of_their_own(): void
    {
        $this->assertSame(21, $this->balance()['entitlement_days']);
    }

    public function test_an_employees_own_entitlement_wins(): void
    {
        DB::table('employees')->where('id', $this->employeeId)->update(['annual_leave_days' => 30]);

        $this->assertSame(30, $this->balance()['entitlement_days']);
    }

    public function test_ten_years_service_raises_the_entitlement_when_the_company_applies_the_rule(): void
    {
        DB::table('tenants')->where('id', $this->tenantId)->update(['apply_legal_seniority_entitlement' => 1]);
        DB::table('employees')->where('id', $this->employeeId)->update(['hire_date' => '2010-01-01']);

        $this->assertSame(30, $this->balance()['entitlement_days']);
    }

    public function test_the_seniority_rule_does_nothing_for_a_company_that_has_not_applied_it(): void
    {
        // The statute applies to Egyptian companies whether or not they tick
        // the box; it must not be imposed on one somewhere else.
        DB::table('employees')->where('id', $this->employeeId)->update(['hire_date' => '2010-01-01']);

        $this->assertSame(21, $this->balance()['entitlement_days']);
    }

    public function test_the_seniority_rule_never_lowers_a_more_generous_entitlement(): void
    {
        DB::table('tenants')->where('id', $this->tenantId)->update(['apply_legal_seniority_entitlement' => 1]);
        DB::table('employees')->where('id', $this->employeeId)
            ->update(['hire_date' => '2010-01-01', 'annual_leave_days' => 40]);

        $this->assertSame(40, $this->balance()['entitlement_days']);
    }

    // ── Days used ────────────────────────────────────────────────────────

    public function test_approved_annual_leave_counts_against_the_balance_inclusively(): void
    {
        // The 10th to the 14th is five days off, not four.
        $this->leave('2026-03-10', '2026-03-14');

        $balance = $this->balance();

        $this->assertSame(5, $balance['used_days']);
        $this->assertSame(16, $balance['remaining_days']);
    }

    public function test_a_request_still_awaiting_a_decision_does_not_consume_the_balance(): void
    {
        $this->leave('2026-03-10', '2026-03-14', 'pending');

        $this->assertSame(0, $this->balance()['used_days']);
    }

    public function test_other_kinds_of_leave_do_not_touch_the_annual_balance(): void
    {
        $this->leave('2026-03-10', '2026-03-14', 'approved', 'sick');

        $this->assertSame(0, $this->balance()['used_days']);
    }

    public function test_last_years_leave_belongs_to_last_years_balance(): void
    {
        $this->leave('2025-03-10', '2025-03-14');

        $this->assertSame(0, $this->balance(2026)['used_days']);
        $this->assertSame(5, $this->balance(2025)['used_days']);
    }

    public function test_carried_days_are_added_on_top_of_the_entitlement(): void
    {
        DB::table('leave_year_balances')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'year' => 2026,
            'entitlement_days' => 21,
            'carried_over_days' => 5,
        ]);

        $balance = $this->balance();

        $this->assertSame(5, $balance['carried_over_days']);
        $this->assertSame(26, $balance['total_days']);
    }

    public function test_an_overdrawn_balance_reports_zero_rather_than_a_negative(): void
    {
        // Being over-drawn is a payroll question, not a leave one; a negative
        // remaining figure would just render as nonsense in the app.
        $this->leave('2026-01-01', '2026-12-31');

        $this->assertSame(0, $this->balance()['remaining_days']);
    }

    // ── Which policy applies ─────────────────────────────────────────────

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function policy(string $scope, ?int $scopeId, array $overrides = []): void
    {
        DB::table('leave_carryover_policies')->insert($overrides + [
            'tenant_id' => $this->tenantId,
            'scope_type' => $scope,
            'scope_id' => $scopeId,
            'min_seniority_months' => 0,
            'carryover_enabled' => 1,
            'carryover_max_days' => 5,
            'encash_excess' => 0,
        ]);
    }

    public function test_a_company_wide_policy_applies_to_everybody(): void
    {
        $this->policy('tenant', null);

        $resolved = CarryoverPolicy::resolve($this->employeeId, $this->tenantId);

        $this->assertTrue($resolved->enabled);
        $this->assertSame(5, $resolved->maxDays);
        $this->assertSame('tenant', $resolved->source);
    }

    public function test_a_personal_policy_beats_the_company_one(): void
    {
        $this->policy('tenant', null);
        $this->policy('employee', $this->employeeId, ['carryover_max_days' => 12]);

        $resolved = CarryoverPolicy::resolve($this->employeeId, $this->tenantId);

        $this->assertSame(12, $resolved->maxDays);
        $this->assertSame('employee', $resolved->source);
    }

    public function test_a_branch_policy_only_reaches_that_branch(): void
    {
        $otherBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Somewhere else',
        ]);
        $this->policy('branch', $otherBranch, ['carryover_max_days' => 99]);

        $this->assertSame('default', CarryoverPolicy::resolve($this->employeeId, $this->tenantId)->source);
    }

    public function test_a_seniority_tier_the_employee_has_not_reached_does_not_apply(): void
    {
        DB::table('employees')->where('id', $this->employeeId)->update(['hire_date' => '2025-01-01']);
        $this->policy('tenant', null, ['carryover_max_days' => 5]);
        $this->policy('tenant', null, ['min_seniority_months' => 120, 'carryover_max_days' => 30]);

        $this->assertSame(5, CarryoverPolicy::resolve($this->employeeId, $this->tenantId)->maxDays);
    }

    public function test_the_highest_tier_the_employee_has_reached_wins(): void
    {
        DB::table('employees')->where('id', $this->employeeId)->update(['hire_date' => '2010-01-01']);
        $this->policy('tenant', null, ['carryover_max_days' => 5]);
        $this->policy('tenant', null, ['min_seniority_months' => 120, 'carryover_max_days' => 30]);

        $this->assertSame(30, CarryoverPolicy::resolve($this->employeeId, $this->tenantId)->maxDays);
    }

    public function test_the_old_single_company_column_is_still_honoured(): void
    {
        // Reading it is the difference between honouring what a company set
        // years ago and silently dropping everybody's carried days.
        DB::table('tenants')->where('id', $this->tenantId)->update(['leave_carryover_max_days' => 7]);

        $resolved = CarryoverPolicy::resolve($this->employeeId, $this->tenantId);

        $this->assertTrue($resolved->enabled);
        $this->assertSame(7, $resolved->maxDays);
        $this->assertSame('legacy', $resolved->source);
    }

    public function test_no_policy_anywhere_means_no_carryover(): void
    {
        $resolved = CarryoverPolicy::resolve($this->employeeId, $this->tenantId);

        $this->assertFalse($resolved->enabled);
        $this->assertSame('default', $resolved->source);
    }

    public function test_a_start_date_in_the_future_is_not_seniority(): void
    {
        $this->assertSame(0, CarryoverPolicy::tenureMonths('2099-01-01'));
        $this->assertSame(0, CarryoverPolicy::tenureMonths(null));
    }
}
