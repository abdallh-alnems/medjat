<?php

declare(strict_types=1);

namespace Tests\Feature\Payroll;

use App\Modules\Auth\Services\FirebaseTokenVerifier;
use App\Modules\Notifications\Domain\PushSender;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\FakeFirebaseTokenVerifier;
use Tests\Support\FakePushSender;
use Tests\TestCase;

/**
 * The financial tab: one person, one month, and how the figure was reached.
 */
final class FinancialSummaryTest extends TestCase
{
    use DatabaseTransactions;

    private const ENDPOINT = '/v1/employees/financial-summary';

    private const MONTH = '2026-02';

    private int $tenantId;

    private int $employeeId;

    private int $adminId;

    private string $adminToken;

    protected function setUp(): void
    {
        parent::setUp();

        $firebase = new FakeFirebaseTokenVerifier;
        $this->app->instance(FirebaseTokenVerifier::class, $firebase);
        $this->app->instance(PushSender::class, new FakePushSender);

        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));
        DB::table('tenants')->where('id', $this->tenantId)->update(['cycle_start_day' => 1]);
        DB::table('deduction_rules')->where('tenant_id', $this->tenantId)->delete();
        DB::table('bonus_rules')->where('tenant_id', $this->tenantId)->delete();

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Financial fixture',
            'status' => 'active',
            'base_salary' => 3000,
            'hire_date' => '2020-01-01',
        ]);

        $uid = 'uid-'.bin2hex(random_bytes(6));
        $this->adminId = (int) DB::table('admins')->insertGetId([
            'firebase_uid' => $uid,
            'tenant_id' => $this->tenantId,
            'name' => 'Payroll manager',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);
        $this->adminToken = $firebase->issue($uid);
    }

    private function asAdmin(): self
    {
        $this->withHeader('X-Firebase-Token', $this->adminToken);

        return $this;
    }

    /**
     * @return TestResponse<\Illuminate\Http\JsonResponse>
     */
    private function fetch(string $month = self::MONTH): TestResponse
    {
        return $this->asAdmin()->getJson(self::ENDPOINT.'?employee_id='.$this->employeeId.'&month='.$month);
    }

    public function test_it_reports_the_live_estimate_while_the_month_is_a_draft(): void
    {
        $this->fetch()
            ->assertOk()
            ->assertJsonPath('data.current.status', 'draft')
            ->assertJsonPath('data.current.locked', false)
            ->assertJsonPath('data.current.base_salary', 3000)
            ->assertJsonPath('data.current.cycle_from', '2026-02-01')
            ->assertJsonPath('data.current.cycle_to', '2026-02-28');
    }

    public function test_an_approved_month_shows_the_frozen_snapshot_not_a_fresh_calculation(): void
    {
        // What HR is looking at then is a decision already made; recalculating
        // it would disagree with the payslip the employee is holding.
        DB::table('payroll')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'month' => self::MONTH,
            'base_salary' => 3000,
            'total_deductions' => 500,
            'total_bonuses' => 0,
            'net_salary' => 2500,
            'status' => 'approved',
            'approved_by' => $this->adminId,
            'breakdown' => json_encode([
                'base_salary' => 3000,
                'total_deductions' => 500,
                'total_bonuses' => 0,
                'net_salary' => 2500,
                'deductions_breakdown' => [],
                'bonuses_breakdown' => [],
            ]),
        ]);

        $this->fetch()
            ->assertOk()
            ->assertJsonPath('data.current.locked', true)
            ->assertJsonPath('data.current.status', 'approved')
            // The live figure would be 3,000; the frozen one is what shows.
            ->assertJsonPath('data.current.net_salary', 2500)
            ->assertJsonPath('data.current.approved_by_name', 'Payroll manager');
    }

    public function test_a_late_arrival_is_counted_as_late_rather_than_present(): void
    {
        // Folding lateness into "present" hides the very thing the deduction
        // came from.
        DB::table('attendance')->insert([
            ['tenant_id' => $this->tenantId, 'employee_id' => $this->employeeId,
                'date' => '2026-02-03', 'status' => 'present', 'late_minutes' => 0, 'worked_minutes' => 480],
            ['tenant_id' => $this->tenantId, 'employee_id' => $this->employeeId,
                'date' => '2026-02-04', 'status' => 'present', 'late_minutes' => 20, 'worked_minutes' => 460],
            ['tenant_id' => $this->tenantId, 'employee_id' => $this->employeeId,
                'date' => '2026-02-05', 'status' => 'absent', 'late_minutes' => 0, 'worked_minutes' => 0],
        ]);

        $this->fetch()
            ->assertOk()
            ->assertJsonPath('data.current.attendance.present', 1)
            ->assertJsonPath('data.current.attendance.late', 1)
            ->assertJsonPath('data.current.attendance.absent', 1)
            ->assertJsonPath('data.current.attendance.late_minutes', 20)
            ->assertJsonPath('data.current.attendance.worked_minutes', 940);
    }

    public function test_the_rules_behind_the_arithmetic_are_reported(): void
    {
        DB::table('deduction_rules')->insert([
            'tenant_id' => $this->tenantId, 'rule_key' => 'absence_multiplier',
            'rule_type' => 'numeric', 'rule_value' => '2', 'is_active' => 1,
        ]);
        DB::table('bonus_rules')->insert([
            'tenant_id' => $this->tenantId, 'rule_key' => 'overtime_multiplier',
            'rule_type' => 'numeric', 'rule_value' => '1.5', 'is_active' => 1,
        ]);

        $this->fetch()
            ->assertOk()
            ->assertJsonPath('data.current.rules.absence_multiplier', 2)
            ->assertJsonPath('data.current.rules.overtime_multiplier', 1.5)
            ->assertJsonPath('data.current.rules.late_type', null);
    }

    public function test_an_outstanding_loan_reports_what_is_left_on_it(): void
    {
        $loanId = (int) DB::table('employee_loans')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'type' => 'loan',
            'total_amount' => 300,
            'installment_amount' => 100,
            'installments_count' => 3,
            'installments_paid' => 1,
            'start_month' => '2026-01',
            'status' => 'active',
        ]);
        DB::table('loan_installments')->insert([
            ['tenant_id' => $this->tenantId, 'loan_id' => $loanId, 'employee_id' => $this->employeeId,
                'month' => '2026-01', 'seq' => 1, 'amount' => 100, 'status' => 'paid'],
            ['tenant_id' => $this->tenantId, 'loan_id' => $loanId, 'employee_id' => $this->employeeId,
                'month' => '2026-02', 'seq' => 2, 'amount' => 100, 'status' => 'pending'],
            ['tenant_id' => $this->tenantId, 'loan_id' => $loanId, 'employee_id' => $this->employeeId,
                'month' => '2026-03', 'seq' => 3, 'amount' => 100, 'status' => 'pending'],
        ]);

        $this->fetch()
            ->assertOk()
            ->assertJsonPath('data.loans.0.paid_amount', 100)
            ->assertJsonPath('data.loans.0.remaining_amount', 200)
            ->assertJsonPath('data.loans.0.remaining_installments', 2)
            ->assertJsonPath('data.loans.0.next_due_month', '2026-02');
    }

    public function test_a_completed_loan_is_not_listed_as_outstanding(): void
    {
        DB::table('employee_loans')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'type' => 'loan',
            'total_amount' => 100,
            'installment_amount' => 100,
            'installments_count' => 1,
            'installments_paid' => 1,
            'start_month' => '2026-01',
            'status' => 'completed',
        ]);

        $this->fetch()->assertOk()->assertJsonPath('data.loans', []);
    }

    public function test_salary_changes_are_read_back_out_of_the_audit_trail(): void
    {
        DB::table('audit_log')->insert([
            'tenant_id' => $this->tenantId,
            'admin_id' => $this->adminId,
            'action' => 'employee.update',
            'target_type' => 'employee',
            'target_id' => (string) $this->employeeId,
            'payload' => json_encode(['base_salary' => 2500]),
        ]);

        $this->fetch()
            ->assertOk()
            ->assertJsonPath('data.salary_history.0.base_salary', 2500)
            ->assertJsonPath('data.salary_history.0.admin_name', 'Payroll manager');
    }

    public function test_an_unrelated_edit_that_merely_mentions_the_words_is_not_a_salary_change(): void
    {
        // The search matches the payload text; only a real base_salary key is a
        // change to report.
        DB::table('audit_log')->insert([
            'tenant_id' => $this->tenantId,
            'admin_id' => $this->adminId,
            'action' => 'employee.update',
            'target_type' => 'employee',
            'target_id' => (string) $this->employeeId,
            'payload' => json_encode(['note' => 'discussed base_salary with them']),
        ]);

        $this->fetch()->assertOk()->assertJsonPath('data.salary_history', []);
    }

    public function test_past_slips_are_listed_newest_first(): void
    {
        foreach (['2026-01', '2026-02'] as $month) {
            DB::table('payroll')->insert([
                'tenant_id' => $this->tenantId,
                'employee_id' => $this->employeeId,
                'month' => $month,
                'base_salary' => 3000,
                'net_salary' => 3000,
                'status' => 'paid',
            ]);
        }

        $this->fetch()
            ->assertOk()
            ->assertJsonPath('data.history.0.month', '2026-02')
            ->assertJsonPath('data.history.1.month', '2026-01');
    }

    public function test_an_employee_at_another_company_is_not_found(): void
    {
        $otherTenant = Value::int(DB::table('tenants')->where('id', '!=', $this->tenantId)->value('id'));
        $stranger = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $otherTenant,
            'name' => 'Somebody else',
            'status' => 'active',
            'base_salary' => 1000,
        ]);

        $this->asAdmin()->getJson(self::ENDPOINT.'?employee_id='.$stranger.'&month='.self::MONTH)
            ->assertNotFound();
    }

    public function test_a_malformed_month_is_refused(): void
    {
        $this->asAdmin()->getJson(self::ENDPOINT.'?employee_id='.$this->employeeId.'&month=2026')
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'invalid_month_format_expected_yyyy');
    }
}
