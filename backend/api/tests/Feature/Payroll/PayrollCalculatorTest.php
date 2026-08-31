<?php

declare(strict_types=1);

namespace Tests\Feature\Payroll;

use App\Modules\Payroll\Domain\PayLineOverrides;
use App\Modules\Payroll\Domain\PayrollCalculator;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * What a payslip adds up to.
 *
 * Every figure here ends up on a document somebody checks against their bank
 * statement, so the tests are written around the arithmetic rather than the
 * plumbing: a base of 3,000 makes the daily rate exactly 100 and the hourly
 * rate exactly 12.50, which keeps the expected numbers readable.
 */
final class PayrollCalculatorTest extends TestCase
{
    use DatabaseTransactions;

    private const MONTH = '2026-02';

    private const BASE = 3000.0;

    private int $tenantId;

    private int $employeeId;

    private PayrollCalculator $calculator;

    protected function setUp(): void
    {
        parent::setUp();

        $this->calculator = app(PayrollCalculator::class);
        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));
        DB::table('tenants')->where('id', $this->tenantId)->update(['cycle_start_day' => 1]);

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Payroll fixture',
            'status' => 'active',
            'base_salary' => self::BASE,
            'hire_date' => '2020-01-01',
        ]);

        // The dump carries real companies with real rules; the arithmetic under
        // test is the calculator's, not whatever a fixture company happens to
        // have configured.
        DB::table('deduction_rules')->where('tenant_id', $this->tenantId)->delete();
        DB::table('bonus_rules')->where('tenant_id', $this->tenantId)->delete();
        DB::table('late_deduction_tiers')->where('tenant_id', $this->tenantId)->delete();
        DB::table('payroll_statutory_settings')->where('tenant_id', $this->tenantId)->delete();
    }

    /**
     * @return array<string, mixed>
     */
    private function calculate(?string $asOf = null): array
    {
        return $this->calculator->calculate($this->employeeId, self::MONTH, $this->tenantId, $asOf);
    }

    /**
     * @param  array<string, mixed>  $extra
     */
    private function attendance(string $date, string $status = 'present', array $extra = []): void
    {
        DB::table('attendance')->insert($extra + [
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'date' => $date,
            'status' => $status,
        ]);
    }

    private function rule(string $key, string $value, string $type = 'numeric', string $table = 'deduction_rules'): void
    {
        DB::table($table)->insert([
            'tenant_id' => $this->tenantId,
            'rule_key' => $key,
            'rule_type' => $type,
            'rule_value' => $value,
            'is_active' => 1,
        ]);
    }

    /**
     * @return array<string, mixed>|null
     */
    private static function lineOfType(mixed $lines, string $type): ?array
    {
        if (! is_array($lines)) {
            return null;
        }

        foreach ($lines as $line) {
            if (is_array($line) && ($line['type'] ?? null) === $type) {
                /** @var array<string, mixed> $line */
                return $line;
            }
        }

        return null;
    }

    /**
     * @return array<string, mixed>
     */
    private static function statutoryOf(mixed $result): array
    {
        self::assertIsArray($result);
        $breakdown = $result['statutory_breakdown'] ?? null;
        self::assertIsArray($breakdown);

        /** @var array<string, mixed> $breakdown */
        return $breakdown;
    }

    // ── The shape of the answer ──────────────────────────────────────────

    public function test_an_unknown_employee_produces_nothing_rather_than_a_zeroed_slip(): void
    {
        // A slip full of zeroes for somebody who does not exist reads as "this
        // person earned nothing", which is a different claim entirely.
        $this->assertSame([], $this->calculator->calculate(9999999, self::MONTH, $this->tenantId));
    }

    public function test_a_clean_month_pays_the_base(): void
    {
        $result = $this->calculate();

        $this->assertSame(self::BASE, $result['base_salary']);
        $this->assertSame(0.0, $result['total_deductions']);
        $this->assertSame(0.0, $result['total_bonuses']);
        $this->assertSame(self::BASE, $result['net_salary']);
        $this->assertSame(28, $result['days_in_cycle']);
    }

    // ── Absence ──────────────────────────────────────────────────────────

    public function test_an_absence_costs_the_daily_rate_times_the_company_multiplier(): void
    {
        $this->rule('absence_multiplier', '1.5');
        $this->attendance('2026-02-10', 'absent');

        $result = $this->calculate();

        $this->assertSame(150.0, $result['total_deductions']);
        $this->assertSame(2850.0, $result['net_salary']);
    }

    public function test_an_absence_falls_back_to_one_and_a_half_days_when_no_rule_is_set(): void
    {
        $this->attendance('2026-02-10', 'absent');

        $this->assertSame(150.0, $this->calculate()['total_deductions']);
    }

    public function test_a_per_day_fixed_override_replaces_the_computed_amount(): void
    {
        $this->attendance('2026-02-10', 'absent', ['deduction_mode' => 'amount', 'deduction_value' => 40]);

        $this->assertSame(40.0, $this->calculate()['total_deductions']);
    }

    public function test_a_per_day_days_override_charges_that_many_daily_rates(): void
    {
        $this->attendance('2026-02-10', 'absent', ['deduction_mode' => 'days', 'deduction_value' => 2]);

        $this->assertSame(200.0, $this->calculate()['total_deductions']);
    }

    // ── Lateness ─────────────────────────────────────────────────────────

    public function test_proportional_lateness_rounds_up_to_the_next_unit(): void
    {
        // A company charging per fifteen minutes means any part of one, which
        // is what the setting says and what staff expect.
        $this->rule('late_type', 'proportional', 'text');
        $this->rule('late_unit_minutes', '15');
        $this->rule('late_deduction_per_unit', '10');
        $this->attendance('2026-02-10', 'present', ['late_minutes' => 16]);

        $this->assertSame(20.0, $this->calculate()['total_deductions']);
    }

    public function test_a_fixed_lateness_rule_charges_the_same_whatever_the_delay(): void
    {
        $this->rule('late_type', 'fixed', 'text');
        $this->rule('late_fixed_amount', '25');
        $this->attendance('2026-02-10', 'present', ['late_minutes' => 90]);

        $this->assertSame(25.0, $this->calculate()['total_deductions']);
    }

    public function test_a_tiered_rule_charges_the_heaviest_tier_the_lateness_reaches(): void
    {
        $this->rule('late_type', 'tiered', 'text');
        foreach ([[10, 0.25], [30, 0.5], [60, 1.0]] as [$threshold, $days]) {
            DB::table('late_deduction_tiers')->insert([
                'tenant_id' => $this->tenantId,
                'threshold_minutes' => $threshold,
                'deduction_days' => $days,
            ]);
        }
        $this->attendance('2026-02-10', 'present', ['late_minutes' => 45]);

        // 45 minutes clears the 30-minute rung but not the 60-minute one.
        $this->assertSame(50.0, $this->calculate()['total_deductions']);
    }

    public function test_lateness_below_every_tier_is_not_charged_at_all(): void
    {
        // Inventing a charge the company never configured is worse than
        // charging nothing.
        $this->rule('late_type', 'tiered', 'text');
        DB::table('late_deduction_tiers')->insert([
            'tenant_id' => $this->tenantId,
            'threshold_minutes' => 30,
            'deduction_days' => 0.5,
        ]);
        $this->attendance('2026-02-10', 'present', ['late_minutes' => 5]);

        $this->assertSame(0.0, $this->calculate()['total_deductions']);
    }

    // ── Overtime and allowances ──────────────────────────────────────────

    public function test_overtime_pays_the_hourly_rate_times_the_multiplier(): void
    {
        $this->rule('overtime_multiplier', '1.5', 'numeric', 'bonus_rules');
        $this->attendance('2026-02-10', 'present', ['overtime_minutes' => 120]);

        // 12.50/hour × 1.5 × 2 hours.
        $this->assertSame(37.5, $this->calculate()['total_bonuses']);
    }

    public function test_a_recurring_allowance_is_paid_for_every_month_it_covers(): void
    {
        DB::table('employee_allowances')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'type' => 'housing',
            'amount' => 500,
            'start_month' => '2026-01',
            'end_month' => null,
        ]);

        $result = $this->calculate();
        $line = self::lineOfType($result['bonuses_breakdown'], 'allowance');

        $this->assertNotNull($line);
        $this->assertSame(500.0, $line['amount']);
        $this->assertSame('بدل سكن', $line['description']);
        $this->assertSame(3500.0, $result['net_salary']);
    }

    public function test_an_allowance_that_has_ended_is_not_paid(): void
    {
        DB::table('employee_allowances')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'type' => 'transport',
            'amount' => 500,
            'start_month' => '2025-01',
            'end_month' => '2025-12',
        ]);

        $this->assertSame(0.0, $this->calculate()['total_bonuses']);
    }

    public function test_a_company_typed_allowance_label_is_shown_as_written(): void
    {
        DB::table('employee_allowances')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'type' => 'other',
            'label' => 'بدل خطر',
            'amount' => 100,
            'start_month' => '2026-01',
        ]);

        $line = self::lineOfType($this->calculate()['bonuses_breakdown'], 'allowance');

        $this->assertNotNull($line);
        $this->assertSame('بدل خطر', $line['description']);
        // Nothing to translate: the words are the company's own.
        $this->assertNull($line['label_key']);
    }

    // ── Manual lines, loans and permissions ──────────────────────────────

    public function test_a_manual_deduction_is_charged_for_the_month_it_names(): void
    {
        DB::table('manual_deductions')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'amount' => 75,
            'reason' => 'Broken equipment',
            'month' => self::MONTH,
        ]);

        $this->assertSame(75.0, $this->calculate()['total_deductions']);
    }

    public function test_a_loan_installment_due_this_month_is_deducted(): void
    {
        $loanId = (int) DB::table('employee_loans')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'type' => 'loan',
            'total_amount' => 1200,
            'installments_count' => 12,
            'installment_amount' => 100,
            'start_month' => '2026-01',
            'status' => 'active',
        ]);
        DB::table('loan_installments')->insert([
            'tenant_id' => $this->tenantId,
            'loan_id' => $loanId,
            'employee_id' => $this->employeeId,
            'month' => self::MONTH,
            'seq' => 2,
            'amount' => 100,
            'status' => 'pending',
        ]);

        $line = self::lineOfType($this->calculate()['deductions_breakdown'], 'loan');

        $this->assertNotNull($line);
        $this->assertSame(100.0, $line['amount']);
        $this->assertSame('قسط قرض (قسط 2)', $line['description']);
    }

    public function test_an_installment_of_a_closed_loan_is_not_charged(): void
    {
        // A loan that has been cancelled or completed stops charging even if a
        // row was left behind pending.
        $loanId = (int) DB::table('employee_loans')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'type' => 'loan',
            'total_amount' => 1200,
            'installments_count' => 12,
            'installment_amount' => 100,
            'start_month' => '2026-01',
            'status' => 'completed',
        ]);
        DB::table('loan_installments')->insert([
            'tenant_id' => $this->tenantId,
            'loan_id' => $loanId,
            'employee_id' => $this->employeeId,
            'month' => self::MONTH,
            'seq' => 2,
            'amount' => 100,
            'status' => 'pending',
        ]);

        $this->assertSame(0.0, $this->calculate()['total_deductions']);
    }

    public function test_an_approved_permission_marked_deductible_costs_its_hours(): void
    {
        DB::table('break_requests')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'date' => '2026-02-10',
            'start_time' => '10:00:00',
            'end_time' => '12:00:00',
            'duration_minutes' => 120,
            'type' => 'إذن شخصي',
            'deduct_from_salary' => 1,
            'status' => 'approved',
        ]);

        // 12.50/hour × 2 hours.
        $this->assertSame(25.0, $this->calculate()['total_deductions']);
    }

    public function test_a_permission_not_marked_deductible_costs_nothing(): void
    {
        DB::table('break_requests')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'date' => '2026-02-10',
            'start_time' => '10:00:00',
            'end_time' => '12:00:00',
            'duration_minutes' => 120,
            'type' => 'إذن شخصي',
            'deduct_from_salary' => 0,
            'status' => 'approved',
        ]);

        $this->assertSame(0.0, $this->calculate()['total_deductions']);
    }

    // ── Suspension ───────────────────────────────────────────────────────

    private function suspend(string $from, ?string $to, string $mode, float $percentage = 0): void
    {
        DB::table('employee_suspensions')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'reason' => 'Investigation',
            'pay_mode' => $mode,
            'pay_percentage' => $percentage,
            'start_date' => $from,
            'end_date' => $to,
        ]);
    }

    public function test_an_unpaid_suspension_costs_the_daily_rate_per_day(): void
    {
        $this->suspend('2026-02-10', '2026-02-14', 'unpaid');

        $this->assertSame(500.0, $this->calculate()['total_deductions']);
    }

    public function test_a_partly_paid_suspension_only_charges_the_unpaid_share(): void
    {
        $this->suspend('2026-02-10', '2026-02-14', 'partial', 60);

        // Five days at 40% of the daily rate.
        $this->assertSame(200.0, $this->calculate()['total_deductions']);
    }

    public function test_a_fully_paid_suspension_costs_nothing(): void
    {
        $this->suspend('2026-02-10', '2026-02-14', 'full');

        $this->assertSame(0.0, $this->calculate()['total_deductions']);
    }

    public function test_an_absence_inside_a_suspension_is_not_charged_twice(): void
    {
        // The day is already paid for by the suspension line; counting the
        // absence as well deducts the same day twice for the same reason.
        $this->suspend('2026-02-10', '2026-02-14', 'unpaid');
        $this->attendance('2026-02-12', 'absent');

        $result = $this->calculate();

        $this->assertSame(500.0, $result['total_deductions']);
        $this->assertNull(self::lineOfType($result['deductions_breakdown'], 'absence'));
    }

    public function test_a_suspension_is_clipped_to_the_cycle(): void
    {
        // It began in January and has not ended; only February's days belong on
        // February's payslip.
        $this->suspend('2026-01-20', null, 'unpaid');

        $this->assertSame(2800.0, $this->calculate()['total_deductions']);
    }

    // ── Proration ────────────────────────────────────────────────────────

    public function test_a_mid_cycle_view_prorates_the_base_and_stops_counting_there(): void
    {
        $this->attendance('2026-02-20', 'absent');

        $result = $this->calculate('2026-02-10');

        $this->assertSame(10, $result['days_elapsed']);
        // 3000 × 10/28.
        $this->assertSame(1071.43, $result['prorated_base_salary']);
        // The absence on the 20th has not happened yet.
        $this->assertSame(0.0, $result['total_deductions']);
        $this->assertSame(1071.43, $result['earned_to_date']);
    }

    public function test_a_cycle_that_has_not_started_has_earned_nothing(): void
    {
        $result = $this->calculate('2026-01-15');

        $this->assertSame(0, $result['days_elapsed']);
        $this->assertSame(0.0, $result['prorated_base_salary']);
        $this->assertSame(0.0, $result['earned_to_date']);
    }

    public function test_deductions_larger_than_the_salary_produce_a_negative_net(): void
    {
        // Clamping at zero hides the situation from HR and makes the following
        // month's arithmetic wrong.
        DB::table('manual_deductions')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'amount' => 4000,
            'reason' => 'Advance recovery',
            'month' => self::MONTH,
        ]);

        $this->assertSame(-1000.0, $this->calculate()['net_salary']);
    }

    // ── Statutory ────────────────────────────────────────────────────────

    /**
     * @param  array<string, mixed>  $settings
     */
    private function statutory(array $settings): void
    {
        DB::table('payroll_statutory_settings')->insert($settings + [
            'tenant_id' => $this->tenantId,
        ]);
    }

    public function test_statutory_deductions_are_absent_until_a_company_turns_them_on(): void
    {
        $this->assertArrayNotHasKey('statutory_breakdown', $this->calculate());
    }

    public function test_the_insurable_wage_is_clamped_into_the_statutory_band(): void
    {
        // Contributions are capped by law, not by salary: above the ceiling
        // everybody pays the ceiling's share.
        $this->statutory([
            'social_insurance_enabled' => 1,
            'si_employee_rate' => 10,
            'si_min_wage' => 1000,
            'si_max_wage' => 2000,
        ]);

        $result = $this->calculate();

        $this->assertSame(200.0, self::statutoryOf($result)['insurance_employee']);
        $this->assertSame(200.0, $result['total_deductions']);
    }

    public function test_insurance_comes_off_before_tax(): void
    {
        // A contribution the employee never received is not income they can be
        // taxed on.
        $this->statutory([
            'social_insurance_enabled' => 1,
            'si_employee_rate' => 10,
            'si_min_wage' => 0,
            'si_max_wage' => 3000,
            'income_tax_enabled' => 1,
            'tax_personal_exemption' => 0,
            'income_tax_brackets' => json_encode([['up_to' => 1000000, 'rate' => 10]]),
        ]);

        $result = $this->calculate();

        $this->assertSame(300.0, self::statutoryOf($result)['insurance_employee']);
        // Taxed on 2,700, not 3,000.
        $this->assertSame(2700.0, self::statutoryOf($result)['taxable_income']);
        $this->assertSame(270.0, self::statutoryOf($result)['income_tax']);
    }

    public function test_tax_walks_the_annual_brackets_rather_than_the_monthly_figure(): void
    {
        // The brackets are annual because that is how the law states them.
        // Taxing a month against annual bands directly would put everybody in
        // the lowest one.
        $this->statutory([
            'income_tax_enabled' => 1,
            'tax_personal_exemption' => 0,
            'income_tax_brackets' => json_encode([
                ['up_to' => 12000, 'rate' => 0],
                ['up_to' => 24000, 'rate' => 10],
                ['up_to' => null, 'rate' => 20],
            ]),
        ]);

        // 36,000 a year: nothing on the first 12k, 1,200 on the next 12k,
        // 2,400 on the last 12k → 3,600 a year → 300 a month.
        $this->assertSame(300.0, self::statutoryOf($this->calculate())['income_tax']);
    }

    // ── Corrections ──────────────────────────────────────────────────────

    public function test_waiving_a_line_removes_it_from_the_payslip(): void
    {
        $this->attendance('2026-02-10', 'absent');
        $line = self::lineOfType($this->calculate()['deductions_breakdown'], 'absence');
        $this->assertNotNull($line);

        PayLineOverrides::save(
            $this->tenantId, $this->employeeId, self::MONTH, 'deduction',
            'absence', Value::string($line['date']), Value::string($line['description']),
            true, null, 'Approved leave', null,
        );

        $result = $this->calculate();

        $this->assertSame(0.0, $result['total_deductions']);
        $this->assertNull(self::lineOfType($result['deductions_breakdown'], 'absence'));
    }

    public function test_an_overridden_line_keeps_the_figure_it_replaced(): void
    {
        // A payslip showing a corrected line without showing what it was
        // corrected from invites the argument it is meant to settle.
        $this->attendance('2026-02-10', 'absent');
        $line = self::lineOfType($this->calculate()['deductions_breakdown'], 'absence');
        $this->assertNotNull($line);

        PayLineOverrides::save(
            $this->tenantId, $this->employeeId, self::MONTH, 'deduction',
            'absence', Value::string($line['date']), Value::string($line['description']),
            false, 50.0, 'Half charged', null,
        );

        $corrected = self::lineOfType($this->calculate()['deductions_breakdown'], 'absence');

        $this->assertNotNull($corrected);
        $this->assertSame(50.0, $corrected['amount']);
        $this->assertSame(150.0, $corrected['original_amount']);
        $this->assertTrue($corrected['overridden']);
    }

    public function test_a_manual_line_is_never_touched_by_an_override(): void
    {
        // Manual rows are already exactly what a person decided, and they are
        // edited through their own form.
        DB::table('manual_deductions')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'amount' => 75,
            'reason' => 'Broken equipment',
            'month' => self::MONTH,
        ]);
        $line = self::lineOfType($this->calculate()['deductions_breakdown'], 'manual');
        $this->assertNotNull($line);

        PayLineOverrides::save(
            $this->tenantId, $this->employeeId, self::MONTH, 'deduction',
            'manual', null, Value::string($line['description']),
            true, null, null, null,
        );

        $this->assertSame(75.0, $this->calculate()['total_deductions']);
    }

    public function test_the_statutory_summary_follows_a_waived_statutory_line(): void
    {
        // The card has to agree with the lines, not with what was computed
        // before the correction was applied.
        $this->statutory([
            'social_insurance_enabled' => 1,
            'si_employee_rate' => 10,
            'si_min_wage' => 0,
            'si_max_wage' => 3000,
        ]);
        $line = self::lineOfType($this->calculate()['deductions_breakdown'], 'social_insurance');
        $this->assertNotNull($line);

        PayLineOverrides::save(
            $this->tenantId, $this->employeeId, self::MONTH, 'deduction',
            'social_insurance', null, Value::string($line['description']),
            true, null, null, null,
        );

        $result = $this->calculate();

        $this->assertSame(0.0, self::statutoryOf($result)['insurance_employee']);
        $this->assertSame(0.0, $result['total_deductions']);
    }

    public function test_a_correction_stops_applying_once_the_line_it_named_changes(): void
    {
        // A waiver granted against one day's absence must not silently carry
        // over to a different line that happens to occupy the same slot.
        $this->attendance('2026-02-10', 'absent');
        $line = self::lineOfType($this->calculate()['deductions_breakdown'], 'absence');
        $this->assertNotNull($line);

        PayLineOverrides::save(
            $this->tenantId, $this->employeeId, self::MONTH, 'deduction',
            'absence', Value::string($line['date']), Value::string($line['description']),
            true, null, null, null,
        );

        DB::table('attendance')
            ->where('employee_id', $this->employeeId)->where('date', '2026-02-10')
            ->update(['date' => '2026-02-11']);

        $this->assertSame(150.0, $this->calculate()['total_deductions']);
    }
}
