<?php

declare(strict_types=1);

namespace App\Domain\Loans;

use App\Support\Value;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Clearing the loan installments a payslip has already deducted.
 *
 * Called after approval, once the deduction is on a frozen slip. Doing it
 * earlier would mark an installment paid against a draft that might still be
 * reverted, and the employee would be charged for it twice.
 */
final class LoanSettlement
{
    public function settleMonth(int $employeeId, string $month, int $tenantId): void
    {
        try {
            $due = DB::table('loan_installments as li')
                ->join('employee_loans as el', 'el.id', '=', 'li.loan_id')
                ->where('li.employee_id', $employeeId)
                ->where('li.tenant_id', $tenantId)
                ->where('li.month', $month)
                ->where('li.status', 'pending')
                ->where('el.status', 'active')
                ->get(['li.id', 'li.loan_id']);

            if ($due->isEmpty()) {
                return;
            }

            // One transaction for the whole month: a half-settled loan — some
            // installments marked paid, the counter not advanced — would quietly
            // charge the employee again next month.
            DB::transaction(function () use ($due, $tenantId): void {
                foreach ($due as $installment) {
                    $loanId = Value::int($installment->loan_id);

                    DB::table('loan_installments')
                        ->where('id', Value::int($installment->id))->where('tenant_id', $tenantId)
                        ->update(['status' => 'paid', 'paid_at' => DB::raw('NOW()')]);

                    DB::table('employee_loans')
                        ->where('id', $loanId)->where('tenant_id', $tenantId)
                        ->update(['installments_paid' => DB::raw('installments_paid + 1')]);

                    // Closing the loan is the same statement's business: a loan
                    // whose last installment was just paid must not stay active
                    // and charge an installment that no longer exists.
                    DB::table('employee_loans')
                        ->where('id', $loanId)->where('tenant_id', $tenantId)
                        ->where('status', 'active')
                        ->whereColumn('installments_paid', '>=', 'installments_count')
                        ->update(['status' => 'completed']);
                }
            });
        } catch (Throwable $e) {
            // A settlement failure must not undo an approval that already
            // succeeded — the slip is correct either way, and an installment
            // left pending is visible and fixable.
            Log::warning('Loan settlement failed', [
                'employee_id' => $employeeId,
                'month' => $month,
                'exception' => $e,
            ]);
        }
    }
}
