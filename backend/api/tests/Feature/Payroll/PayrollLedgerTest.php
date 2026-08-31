<?php

declare(strict_types=1);

namespace Tests\Feature\Payroll;

use App\Modules\Payroll\Domain\PayrollLedger;
use App\Support\Value;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Saved slips, and the states they move through.
 */
final class PayrollLedgerTest extends TestCase
{
    use DatabaseTransactions;

    private const MONTH = '2026-02';

    private int $tenantId;

    private int $branchId;

    private int $employeeId;

    private int $adminId;

    private PayrollLedger $ledger;

    protected function setUp(): void
    {
        parent::setUp();

        $this->ledger = app(PayrollLedger::class);
        $this->tenantId = Value::int(DB::table('tenants')->orderBy('id')->value('id'));
        DB::table('tenants')->where('id', $this->tenantId)->update(['cycle_start_day' => 1]);

        $this->branchId = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Ledger branch',
        ]);

        $this->employeeId = (int) DB::table('employees')->insertGetId([
            'tenant_id' => $this->tenantId,
            'name' => 'Ledger fixture',
            'status' => 'active',
            'base_salary' => 3000,
            'branch_id' => $this->branchId,
            'hire_date' => '2020-01-01',
        ]);

        $this->adminId = (int) DB::table('admins')->insertGetId([
            'firebase_uid' => 'uid-'.bin2hex(random_bytes(6)),
            'tenant_id' => $this->tenantId,
            'name' => 'Payroll manager',
            'role' => 'general_manager',
            'is_active' => 1,
        ]);
    }

    private function slipId(): int
    {
        return Value::int(DB::table('payroll')
            ->where('employee_id', $this->employeeId)->where('month', self::MONTH)
            ->value('id'));
    }

    private function slipStatus(): string
    {
        return Value::string(DB::table('payroll')->where('id', $this->slipId())->value('status'));
    }

    // ── Generating ───────────────────────────────────────────────────────

    public function test_generating_writes_a_draft_slip(): void
    {
        $this->ledger->generate($this->tenantId, self::MONTH, $this->branchId);

        $this->assertDatabaseHas('payroll', [
            'employee_id' => $this->employeeId,
            'month' => self::MONTH,
            'status' => 'draft',
            'net_salary' => '3000.00',
        ]);
    }

    public function test_generating_twice_refreshes_the_slip_instead_of_duplicating_it(): void
    {
        $this->ledger->generate($this->tenantId, self::MONTH, $this->branchId);

        DB::table('manual_deductions')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'amount' => 500,
            'reason' => 'Correction',
            'month' => self::MONTH,
        ]);

        $this->ledger->generate($this->tenantId, self::MONTH, $this->branchId);

        $this->assertSame(1, DB::table('payroll')
            ->where('employee_id', $this->employeeId)->where('month', self::MONTH)->count());
        $this->assertSame('2500.00', DB::table('payroll')->where('id', $this->slipId())->value('net_salary'));
    }

    public function test_a_generated_slip_carries_the_employees_own_branch(): void
    {
        // Not the branch that was being filtered on. Stamping the filter meant a
        // run over everybody wrote NULL, and the branch-filtered slip list came
        // back empty afterwards.
        $this->ledger->generate($this->tenantId, self::MONTH, null);

        $this->assertSame(
            $this->branchId,
            Value::int(DB::table('payroll')->where('id', $this->slipId())->value('branch_id'))
        );
    }

    // ── Approving ────────────────────────────────────────────────────────

    public function test_approval_re_freezes_the_slip_at_its_final_figures(): void
    {
        // Approval is the decision that fixes the amount, so the amount
        // recorded must be the one the approver was deciding about.
        $this->ledger->generate($this->tenantId, self::MONTH, null);

        DB::table('manual_deductions')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'amount' => 500,
            'reason' => 'Late correction',
            'month' => self::MONTH,
        ]);

        $this->ledger->approve($this->slipId(), $this->tenantId, $this->adminId);

        $this->assertSame('approved', $this->slipStatus());
        $this->assertSame('2500.00', DB::table('payroll')->where('id', $this->slipId())->value('net_salary'));
    }

    public function test_bulk_approval_re_freezes_exactly_as_a_single_approval_does(): void
    {
        // The same decision must not produce two different payslips depending
        // on which button was pressed.
        $this->ledger->generate($this->tenantId, self::MONTH, null);

        DB::table('manual_deductions')->insert([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'amount' => 500,
            'reason' => 'Late correction',
            'month' => self::MONTH,
        ]);

        $this->ledger->approveMany([$this->slipId()], $this->tenantId, $this->adminId);

        $this->assertSame('approved', $this->slipStatus());
        $this->assertSame('2500.00', DB::table('payroll')->where('id', $this->slipId())->value('net_salary'));
    }

    public function test_approval_settles_a_pending_leave_encashment(): void
    {
        $this->ledger->generate($this->tenantId, self::MONTH, null);

        $encashmentId = (int) DB::table('leave_encashments')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'source_year' => 2025,
            'days' => 5,
            'daily_rate' => 100,
            'amount' => 500,
            'status' => 'pending',
        ]);

        $this->ledger->approve($this->slipId(), $this->tenantId, $this->adminId);

        $this->assertDatabaseHas('leave_encashments', [
            'id' => $encashmentId,
            'status' => 'paid',
            'payroll_month' => self::MONTH,
        ]);
    }

    public function test_approving_a_slip_that_does_not_exist_reports_it(): void
    {
        $this->assertNull($this->ledger->approve(9999999, $this->tenantId, $this->adminId));
    }

    public function test_a_slip_belonging_to_another_company_is_not_approvable(): void
    {
        // The id is a small integer; without the tenant check this approves
        // payroll at a company the caller has nothing to do with.
        $this->ledger->generate($this->tenantId, self::MONTH, null);
        $otherTenant = Value::int(DB::table('tenants')->where('id', '!=', $this->tenantId)->value('id'));

        $this->assertNull($this->ledger->approve($this->slipId(), $otherTenant, $this->adminId));
        $this->assertSame('draft', $this->slipStatus());
    }

    public function test_bulk_approval_skips_rows_that_are_not_drafts(): void
    {
        // The screen offers "approve all" over a mixed selection; failing the
        // whole call because one row was already approved helps nobody.
        $this->ledger->generate($this->tenantId, self::MONTH, null);
        $id = $this->slipId();
        $this->ledger->approve($id, $this->tenantId, $this->adminId);

        $this->assertSame([], $this->ledger->approveMany([$id], $this->tenantId, $this->adminId));
    }

    // ── Paying ───────────────────────────────────────────────────────────

    public function test_only_approved_slips_can_be_marked_paid(): void
    {
        $this->ledger->generate($this->tenantId, self::MONTH, null);

        $this->assertSame([], $this->ledger->markPaidMany([$this->slipId()], $this->tenantId));
        $this->assertSame('draft', $this->slipStatus());
    }

    public function test_a_supplied_payment_date_is_recorded_as_given(): void
    {
        $this->ledger->generate($this->tenantId, self::MONTH, null);
        $this->ledger->approve($this->slipId(), $this->tenantId, $this->adminId);
        $this->ledger->markPaidMany([$this->slipId()], $this->tenantId, '2026-03-02');

        $this->assertSame('paid', $this->slipStatus());
        $this->assertStringStartsWith(
            '2026-03-02',
            Value::string(DB::table('payroll')->where('id', $this->slipId())->value('paid_at'))
        );
    }

    // ── Reverting ────────────────────────────────────────────────────────

    public function test_reverting_steps_paid_back_to_approved_and_clears_the_date(): void
    {
        $this->ledger->generate($this->tenantId, self::MONTH, null);
        $this->ledger->approve($this->slipId(), $this->tenantId, $this->adminId);
        $this->ledger->markPaidMany([$this->slipId()], $this->tenantId, '2026-03-02');

        $this->assertSame('paid', $this->ledger->revert($this->slipId(), $this->tenantId));
        $this->assertSame('approved', $this->slipStatus());
        $this->assertNull(DB::table('payroll')->where('id', $this->slipId())->value('paid_at'));
    }

    public function test_reverting_an_approved_slip_returns_it_to_draft_and_forgets_who_approved_it(): void
    {
        $this->ledger->generate($this->tenantId, self::MONTH, null);
        $this->ledger->approve($this->slipId(), $this->tenantId, $this->adminId);

        $this->assertSame('approved', $this->ledger->revert($this->slipId(), $this->tenantId));
        $this->assertSame('draft', $this->slipStatus());
        $this->assertNull(DB::table('payroll')->where('id', $this->slipId())->value('approved_by'));
    }

    public function test_a_draft_has_nowhere_left_to_go(): void
    {
        $this->ledger->generate($this->tenantId, self::MONTH, null);

        $this->assertNull($this->ledger->revert($this->slipId(), $this->tenantId));
    }

    // ── Disbursing ───────────────────────────────────────────────────────

    public function test_disbursing_creates_approves_and_pays_in_one_step(): void
    {
        $result = $this->ledger->disburse($this->employeeId, self::MONTH, $this->tenantId, $this->adminId);

        $this->assertSame('paid', $result['result']);
        $this->assertSame('paid', $this->slipStatus());
        $this->assertSame('3000.00', DB::table('payroll')->where('id', $this->slipId())->value('net_salary'));
    }

    public function test_disbursing_twice_does_not_pay_twice(): void
    {
        $this->ledger->disburse($this->employeeId, self::MONTH, $this->tenantId, $this->adminId);
        $again = $this->ledger->disburse($this->employeeId, self::MONTH, $this->tenantId, $this->adminId);

        $this->assertSame('already_paid', $again['result']);
        $this->assertSame(1, DB::table('payroll')
            ->where('employee_id', $this->employeeId)->where('month', self::MONTH)->count());
    }

    public function test_disbursing_settles_the_loan_installments_it_deducted(): void
    {
        // Settled only after approval: doing it against a draft that might be
        // reverted would charge the employee for the same installment twice.
        $loanId = (int) DB::table('employee_loans')->insertGetId([
            'tenant_id' => $this->tenantId,
            'employee_id' => $this->employeeId,
            'type' => 'loan',
            'total_amount' => 200,
            'installment_amount' => 100,
            'installments_count' => 2,
            'installments_paid' => 1,
            'start_month' => '2026-01',
            'status' => 'active',
        ]);
        $installmentId = (int) DB::table('loan_installments')->insertGetId([
            'tenant_id' => $this->tenantId,
            'loan_id' => $loanId,
            'employee_id' => $this->employeeId,
            'month' => self::MONTH,
            'seq' => 2,
            'amount' => 100,
            'status' => 'pending',
        ]);

        $this->ledger->disburse($this->employeeId, self::MONTH, $this->tenantId, $this->adminId);

        $this->assertDatabaseHas('loan_installments', ['id' => $installmentId, 'status' => 'paid']);
        // The last installment closes the loan, so it cannot charge an
        // installment that no longer exists.
        $this->assertDatabaseHas('employee_loans', [
            'id' => $loanId,
            'installments_paid' => 2,
            'status' => 'completed',
        ]);
    }

    public function test_disbursing_an_unknown_employee_is_skipped_rather_than_written(): void
    {
        $result = $this->ledger->disburse(9999999, self::MONTH, $this->tenantId, $this->adminId);

        $this->assertSame('skipped', $result['result']);
        $this->assertNull($result['payroll_id']);
    }

    // ── Locking ──────────────────────────────────────────────────────────

    public function test_frozen_slips_are_reported_so_pointless_adjustments_can_be_refused(): void
    {
        $this->ledger->generate($this->tenantId, self::MONTH, null);
        $this->ledger->approve($this->slipId(), $this->tenantId, $this->adminId);

        $this->assertSame(
            [$this->employeeId],
            $this->ledger->lockedEmployeeIds($this->tenantId, self::MONTH, [$this->employeeId])
        );
    }

    public function test_a_draft_slip_is_not_locked(): void
    {
        $this->ledger->generate($this->tenantId, self::MONTH, null);

        $this->assertSame([], $this->ledger->lockedEmployeeIds($this->tenantId, self::MONTH, [$this->employeeId]));
    }
}
