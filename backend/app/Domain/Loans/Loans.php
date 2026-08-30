<?php

declare(strict_types=1);

namespace App\Domain\Loans;

use App\Support\Value;
use DateTimeImmutable;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * Loans and salary advances, and the installments that repay them.
 *
 * The schedule is generated on approval rather than on creation: a request
 * nobody has agreed to has no installments to deduct, and generating them
 * early would put a pending request into somebody's payroll.
 */
final class Loans
{
    public const TYPES = ['loan', 'advance'];

    /** How many undecided requests one person may have outstanding. */
    public const PENDING_LIMIT = 3;

    public static function create(
        int $tenantId,
        int $employeeId,
        string $type,
        float $totalAmount,
        float $installmentAmount,
        int $installmentsCount,
        string $startMonth,
        ?string $reason,
        ?int $createdBy,
    ): int {
        return (int) DB::table('employee_loans')->insertGetId([
            'tenant_id' => $tenantId,
            'employee_id' => $employeeId,
            'type' => $type,
            'total_amount' => $totalAmount,
            'installment_amount' => $installmentAmount,
            'installments_count' => $installmentsCount,
            'start_month' => $startMonth,
            'reason' => $reason,
            'status' => 'pending',
            'created_by' => $createdBy,
        ]);
    }

    /**
     * @return array<string, mixed>|null
     */
    public static function find(int $id, int $tenantId): ?array
    {
        $row = DB::table('employee_loans as el')
            ->join('employees as e', 'e.id', '=', 'el.employee_id')
            ->where('el.id', $id)->where('el.tenant_id', $tenantId)
            ->first(['el.*', 'e.name as employee_name']);

        return $row === null ? null : self::toArray($row);
    }

    /**
     * @return list<array<string, mixed>>
     */
    public static function forTenant(int $tenantId, ?string $status = null, ?int $employeeId = null): array
    {
        $rows = DB::table('employee_loans as el')
            ->join('employees as e', 'e.id', '=', 'el.employee_id')
            ->where('el.tenant_id', $tenantId)
            ->when($status !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('el.status', $status))
            ->when($employeeId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('el.employee_id', $employeeId))
            ->orderByDesc('el.created_at')
            ->get(['el.*', 'e.name as employee_name'])
            ->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    /**
     * @return list<array<string, mixed>>
     */
    public static function installments(int $loanId, int $tenantId): array
    {
        $rows = DB::table('loan_installments')
            ->where('loan_id', $loanId)->where('tenant_id', $tenantId)
            ->orderBy('seq')
            ->get()->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    /**
     * What this employee still owes across every live loan.
     *
     * Summed from the unpaid installments rather than from the loan header:
     * the header records what was borrowed, and only the schedule knows how
     * much of it has actually come out of a payslip.
     */
    public static function outstandingForEmployee(int $employeeId, int $tenantId): float
    {
        return round(Value::float(
            DB::table('loan_installments as li')
                ->join('employee_loans as el', 'el.id', '=', 'li.loan_id')
                ->where('el.employee_id', $employeeId)
                ->where('el.tenant_id', $tenantId)
                ->whereIn('el.status', ['pending', 'active'])
                ->where('li.status', 'pending')
                ->sum('li.amount')
        ), 2);
    }

    public static function pendingCountForEmployee(int $employeeId, int $tenantId): int
    {
        return DB::table('employee_loans')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)->where('status', 'pending')
            ->count();
    }

    /**
     * Approves a request and writes its repayment schedule.
     *
     * The last installment absorbs the rounding, so the installments always sum
     * to exactly what was borrowed. Dividing evenly and rounding each one would
     * leave a company collecting a few piastres more or less than it lent.
     */
    public static function approve(int $loanId, int $tenantId, int $adminId): bool
    {
        $loan = self::find($loanId, $tenantId);

        if ($loan === null || Value::string($loan['status'] ?? null) !== 'pending') {
            return false;
        }

        $count = max(1, Value::int($loan['installments_count'] ?? null));
        $total = round(Value::float($loan['total_amount'] ?? null), 2);
        $perInstallment = round(Value::float($loan['installment_amount'] ?? null), 2);
        $employeeId = Value::int($loan['employee_id'] ?? null);

        DB::transaction(function () use ($loanId, $tenantId, $adminId, $loan, $count, $total, $perInstallment, $employeeId): void {
            DB::table('employee_loans')->where('id', $loanId)->where('tenant_id', $tenantId)->update([
                'status' => 'active',
                'approved_by' => $adminId,
                'approved_at' => DB::raw('NOW()'),
            ]);

            $month = self::parseMonth(Value::string($loan['start_month'] ?? null));
            $accumulated = 0.0;
            $rows = [];

            for ($seq = 1; $seq <= $count; $seq++) {
                $amount = $seq === $count ? round($total - $accumulated, 2) : $perInstallment;
                $accumulated = round($accumulated + $amount, 2);

                $rows[] = [
                    'tenant_id' => $tenantId,
                    'loan_id' => $loanId,
                    'employee_id' => $employeeId,
                    'month' => $month->format('Y-m'),
                    'seq' => $seq,
                    'amount' => $amount,
                    'status' => 'pending',
                ];

                $month = $month->modify('+1 month');
            }

            DB::table('loan_installments')->insert($rows);
        });

        return true;
    }

    /**
     * Refuses a request nobody has approved.
     *
     * Distinct from cancelling, so the employee's history shows a decision
     * rather than a withdrawal. No installments exist yet, so there is nothing
     * to clean up.
     */
    public static function reject(int $loanId, int $tenantId): bool
    {
        $loan = self::find($loanId, $tenantId);

        if ($loan === null || Value::string($loan['status'] ?? null) !== 'pending') {
            return false;
        }

        DB::table('employee_loans')->where('id', $loanId)->where('tenant_id', $tenantId)
            ->update(['status' => 'rejected']);

        return true;
    }

    /**
     * Stops a loan that is already running.
     *
     * Unpaid installments are dropped so they stop reaching payroll; paid ones
     * stay, because that money was actually deducted.
     */
    public static function cancel(int $loanId, int $tenantId): bool
    {
        $loan = self::find($loanId, $tenantId);

        if ($loan === null || in_array(Value::string($loan['status'] ?? null), ['completed', 'cancelled'], true)) {
            return false;
        }

        DB::transaction(function () use ($loanId, $tenantId): void {
            DB::table('employee_loans')->where('id', $loanId)->where('tenant_id', $tenantId)
                ->update(['status' => 'cancelled']);

            DB::table('loan_installments')
                ->where('loan_id', $loanId)->where('tenant_id', $tenantId)->where('status', 'pending')
                ->delete();
        });

        return true;
    }

    /**
     * A month that does not parse falls back to this one rather than throwing:
     * an approval must not fail because of a malformed month on a row that was
     * already accepted.
     */
    private static function parseMonth(string $month): DateTimeImmutable
    {
        $parsed = DateTimeImmutable::createFromFormat('!Y-m-d', $month.'-01');

        return $parsed === false ? new DateTimeImmutable('first day of this month') : $parsed;
    }

    /**
     * @return array<string, mixed>
     */
    private static function toArray(mixed $row): array
    {
        /** @var array<string, mixed> $columns */
        $columns = (array) $row;

        return $columns;
    }
}
