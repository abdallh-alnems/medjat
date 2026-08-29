<?php

declare(strict_types=1);

namespace App\Domain\Payroll;

use App\Domain\Leave\LeaveEncashment;
use App\Domain\Loans\LoanSettlement;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * Saved payslips and the states they move through.
 *
 * A slip is draft → approved → paid, and the point of saving one at all is the
 * freeze: while it is a draft the figures are recomputed on every read, and the
 * moment it is approved they stop moving. Approval re-runs the calculator one
 * last time with no as-of clamp — the frozen number is the *full* cycle, not
 * whatever had been earned at the instant somebody pressed the button.
 */
final class PayrollLedger
{
    public function __construct(
        private readonly PayrollCalculator $calculator,
        private readonly LeaveEncashment $encashments,
        private readonly LoanSettlement $loans,
    ) {}

    /**
     * Write a draft slip for every active employee in scope.
     *
     * @return list<array<string, mixed>> One calculation per employee.
     */
    public function generate(int $tenantId, string $month, ?int $branchId = null): array
    {
        $employees = DB::table('employees')
            ->where('tenant_id', $tenantId)
            ->where('status', 'active')
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('branch_id', $branchId))
            ->get(['id', 'branch_id']);

        $results = [];

        foreach ($employees as $employee) {
            $employeeId = Value::int($employee->id);
            $calculation = $this->calculator->calculate($employeeId, $month, $tenantId);

            if ($calculation === []) {
                continue;
            }

            // The slip carries the employee's own branch, not whichever branch
            // was being filtered on. The original stamped the filter, so a run
            // over everybody wrote NULL and the branch-filtered slip list came
            // back empty afterwards. Disbursement already recorded the real
            // branch, so the two paths now agree.
            $this->upsertSlip($tenantId, $employeeId, Value::nullableInt($employee->branch_id), $month, $calculation);
            $results[] = $calculation;
        }

        return $results;
    }

    /**
     * @param  array<string, mixed>  $calculation
     */
    private function upsertSlip(int $tenantId, int $employeeId, ?int $branchId, string $month, array $calculation): void
    {
        DB::table('payroll')->upsert(
            [[
                'tenant_id' => $tenantId,
                'employee_id' => $employeeId,
                'branch_id' => $branchId,
                'month' => $month,
                'base_salary' => $calculation['base_salary'],
                'total_deductions' => $calculation['total_deductions'],
                'total_bonuses' => $calculation['total_bonuses'],
                'net_salary' => $calculation['net_salary'],
                'breakdown' => self::encode($calculation),
            ]],
            ['employee_id', 'month'],
            ['base_salary', 'total_deductions', 'total_bonuses', 'net_salary', 'breakdown'],
        );
    }

    /**
     * @return array<string, mixed>|null
     */
    public function slip(int $employeeId, string $month, int $tenantId): ?array
    {
        $row = DB::table('payroll')
            ->where('employee_id', $employeeId)->where('month', $month)->where('tenant_id', $tenantId)
            ->first();

        return $row === null ? null : self::toArray($row);
    }

    /**
     * @return array{items: list<array<string, mixed>>, page: int}
     */
    public function slipsForMonth(int $tenantId, string $month, ?int $branchId, int $page, int $limit = 20): array
    {
        $rows = DB::table('payroll as p')
            ->join('employees as e', 'e.id', '=', 'p.employee_id')
            ->leftJoin('branches as b', 'b.id', '=', 'p.branch_id')
            ->where('p.tenant_id', $tenantId)
            ->where('p.month', $month)
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('p.branch_id', $branchId))
            ->orderBy('e.name')
            ->limit($limit)->offset(($page - 1) * $limit)
            ->get(['p.*', 'e.name as employee_name', 'e.job_title', 'b.name as branch_name'])
            ->all();

        return ['items' => self::rows($rows), 'page' => $page];
    }

    /**
     * Freeze one slip at its full-cycle figures and approve it.
     *
     * The re-freeze happens before the status flips: approving is the decision
     * that fixes the amount, so the amount recorded has to be the one the
     * approver was deciding about, not the partial figure a draft was carrying
     * from whenever it happened to be generated.
     *
     * @return array{id: int, employee_id: int, month: string}|null
     */
    public function approve(int $payrollId, int $tenantId, int $adminId): ?array
    {
        $slip = DB::table('payroll')
            ->where('id', $payrollId)->where('tenant_id', $tenantId)
            ->first(['employee_id', 'month']);

        if ($slip === null) {
            return null;
        }

        $employeeId = Value::int($slip->employee_id);
        $month = Value::string($slip->month);

        $this->refreeze($payrollId, $tenantId, $employeeId, $month);

        DB::table('payroll')
            ->where('id', $payrollId)->where('tenant_id', $tenantId)
            ->update([
                'status' => 'approved',
                'approved_by' => $adminId,
                'approved_at' => DB::raw('NOW()'),
            ]);

        $this->encashments->markPaid([$employeeId], $month, $tenantId);

        return ['id' => $payrollId, 'employee_id' => $employeeId, 'month' => $month];
    }

    private function refreeze(int $payrollId, int $tenantId, int $employeeId, string $month): void
    {
        $final = $this->calculator->calculate($employeeId, $month, $tenantId);

        if ($final === []) {
            return;
        }

        DB::table('payroll')
            ->where('id', $payrollId)->where('tenant_id', $tenantId)
            ->update([
                'base_salary' => $final['base_salary'],
                'total_deductions' => $final['total_deductions'],
                'total_bonuses' => $final['total_bonuses'],
                'net_salary' => $final['net_salary'],
                'breakdown' => self::encode($final),
            ]);
    }

    /**
     * One state backwards: paid → approved, approved → draft.
     *
     * Corrections happen by stepping a slip back rather than deleting it, so
     * the row keeps its identity and its audit trail. Returns the status it
     * came from, or null when there was nothing to step back.
     */
    public function revert(int $payrollId, int $tenantId): ?string
    {
        $status = DB::table('payroll')
            ->where('id', $payrollId)->where('tenant_id', $tenantId)
            ->value('status');

        if ($status === null) {
            return null;
        }

        $from = Value::string($status);

        if ($from === 'paid') {
            DB::table('payroll')->where('id', $payrollId)->where('tenant_id', $tenantId)
                ->update(['status' => 'approved', 'paid_at' => null]);

            return 'paid';
        }

        if ($from === 'approved') {
            DB::table('payroll')->where('id', $payrollId)->where('tenant_id', $tenantId)
                ->update(['status' => 'draft', 'approved_by' => null, 'approved_at' => null]);

            return 'approved';
        }

        return null;
    }

    /**
     * Approve every draft among the given ids.
     *
     * Ids that are not drafts are skipped rather than rejected: the screen
     * offers "approve all" over a mixed selection, and failing the whole call
     * because one row was already approved would be useless to the user.
     *
     * Each slip is re-frozen first, exactly as a single approval does. The
     * original skipped that here, so approving fifty people at once locked
     * figures that approving them one at a time would have refreshed — the same
     * decision producing two different payslips depending on which button was
     * pressed.
     *
     * @param  list<int>  $ids
     * @return list<array<string, mixed>> The rows actually flipped.
     */
    public function approveMany(array $ids, int $tenantId, int $adminId): array
    {
        $touched = $this->pending($ids, $tenantId, 'draft');

        if ($touched === []) {
            return [];
        }

        foreach ($touched as $row) {
            $this->refreeze(
                Value::int($row['id'] ?? null),
                $tenantId,
                Value::int($row['employee_id'] ?? null),
                Value::string($row['month'] ?? null),
            );
        }

        DB::table('payroll')
            ->whereIn('id', array_map(static fn (array $r): int => Value::int($r['id'] ?? null), $touched))
            ->where('tenant_id', $tenantId)
            ->update(['status' => 'approved', 'approved_by' => $adminId, 'approved_at' => DB::raw('NOW()')]);

        $byMonth = [];
        foreach ($touched as $row) {
            $byMonth[Value::string($row['month'] ?? null)][] = Value::int($row['employee_id'] ?? null);
        }
        foreach ($byMonth as $month => $employeeIds) {
            $this->encashments->markPaid($employeeIds, (string) $month, $tenantId);
        }

        return $touched;
    }

    /**
     * @param  list<int>  $ids
     * @return list<array<string, mixed>> The rows actually flipped.
     */
    public function markPaidMany(array $ids, int $tenantId, ?string $paidAt = null): array
    {
        $touched = $this->pending($ids, $tenantId, 'approved');

        if ($touched === []) {
            return [];
        }

        DB::table('payroll')
            ->whereIn('id', array_map(static fn (array $r): int => Value::int($r['id'] ?? null), $touched))
            ->where('tenant_id', $tenantId)
            ->update(['status' => 'paid', 'paid_at' => $paidAt ?? DB::raw('NOW()')]);

        return $touched;
    }

    /**
     * @param  list<int>  $ids
     * @return list<array<string, mixed>>
     */
    private function pending(array $ids, int $tenantId, string $status): array
    {
        $ids = array_values(array_filter($ids, static fn (int $id): bool => $id > 0));

        if ($ids === []) {
            return [];
        }

        $rows = DB::table('payroll')
            ->whereIn('id', $ids)->where('tenant_id', $tenantId)->where('status', $status)
            ->get(['id', 'employee_id', 'month'])
            ->all();

        return self::rows($rows);
    }

    /**
     * Take one employee's slip all the way to paid, creating it if need be.
     *
     * The screen offers a single "pay this person" button, and behind it the
     * slip may not exist at all, or may be a draft, or may already be approved.
     * Collapsing the state machine here keeps that button honest — and keeps
     * the draft → approved step identical to a manual approval, re-freeze and
     * loan settlement included, so the two routes cannot drift apart.
     *
     * @return array{result: string, payroll_id: int|null, employee_id: int, month: string}
     */
    public function disburse(int $employeeId, string $month, int $tenantId, int $adminId, ?string $paidAt = null): array
    {
        $existing = DB::table('payroll')
            ->where('employee_id', $employeeId)->where('month', $month)->where('tenant_id', $tenantId)
            ->first(['id', 'status']);

        if ($existing !== null) {
            $payrollId = Value::int($existing->id);
            $status = Value::string($existing->status);
        } else {
            $calculation = $this->calculator->calculate($employeeId, $month, $tenantId);

            if ($calculation === []) {
                return ['result' => 'skipped', 'payroll_id' => null, 'employee_id' => $employeeId, 'month' => $month];
            }

            $branchId = Value::nullableInt(DB::table('employees')
                ->where('id', $employeeId)->where('tenant_id', $tenantId)->value('branch_id'));

            $payrollId = (int) DB::table('payroll')->insertGetId([
                'tenant_id' => $tenantId,
                'employee_id' => $employeeId,
                'branch_id' => $branchId,
                'month' => $month,
                'base_salary' => $calculation['base_salary'],
                'total_deductions' => $calculation['total_deductions'],
                'total_bonuses' => $calculation['total_bonuses'],
                'net_salary' => $calculation['net_salary'],
                'breakdown' => self::encode($calculation),
                'status' => 'draft',
            ]);
            $status = 'draft';
        }

        if ($status === 'paid') {
            return ['result' => 'already_paid', 'payroll_id' => $payrollId, 'employee_id' => $employeeId, 'month' => $month];
        }

        if ($status === 'draft') {
            $this->approve($payrollId, $tenantId, $adminId);
            $this->loans->settleMonth($employeeId, $month, $tenantId);
            $status = 'approved';
        }

        if ($status === 'approved') {
            $this->markPaidMany([$payrollId], $tenantId, $paidAt);
        }

        return ['result' => 'paid', 'payroll_id' => $payrollId, 'employee_id' => $employeeId, 'month' => $month];
    }

    /**
     * Of these employees, the ones whose slip for the month is already frozen.
     *
     * A later adjustment would not move their net pay, so callers warn instead
     * of silently recording something with no effect.
     *
     * @param  list<int>  $employeeIds
     * @return list<int>
     */
    public function lockedEmployeeIds(int $tenantId, string $month, array $employeeIds): array
    {
        if ($employeeIds === []) {
            return [];
        }

        $locked = DB::table('payroll')
            ->where('tenant_id', $tenantId)->where('month', $month)
            ->whereIn('status', ['approved', 'paid'])
            ->whereIn('employee_id', $employeeIds)
            ->pluck('employee_id')
            ->map(static fn (mixed $id): int => Value::int($id))
            ->values()->all();

        return array_values($locked);
    }

    /**
     * @return array<string, mixed>
     */
    public function summary(int $tenantId, string $month, ?int $branchId = null): array
    {
        $row = DB::table('payroll')
            ->where('tenant_id', $tenantId)->where('month', $month)
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('branch_id', $branchId))
            ->selectRaw(
                'COUNT(*) as employee_count,'
                ."COUNT(CASE WHEN status = 'draft' THEN 1 END) as draft_count,"
                ."COUNT(CASE WHEN status = 'approved' THEN 1 END) as approved_count,"
                ."COUNT(CASE WHEN status = 'paid' THEN 1 END) as paid_count,"
                .'COALESCE(SUM(base_salary), 0) as total_base,'
                .'COALESCE(SUM(total_deductions), 0) as total_deductions,'
                .'COALESCE(SUM(total_bonuses), 0) as total_bonuses,'
                .'COALESCE(SUM(overtime_total_minutes), 0) as total_overtime_minutes,'
                .'COALESCE(SUM(net_salary), 0) as total_net'
            )
            ->first();

        return $row === null ? [] : self::toArray($row);
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function reportRows(int $tenantId, string $month, ?int $branchId = null): array
    {
        $rows = DB::table('payroll as p')
            ->join('employees as e', 'e.id', '=', 'p.employee_id')
            ->leftJoin('branches as b', 'b.id', '=', 'p.branch_id')
            ->where('p.tenant_id', $tenantId)->where('p.month', $month)
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('p.branch_id', $branchId))
            ->orderBy('e.name')
            ->get([
                'p.id', 'p.employee_id', 'e.name as employee_name', 'e.job_title', 'b.name as branch_name',
                'p.base_salary', 'p.total_deductions', 'p.total_bonuses', 'p.overtime_total_minutes',
                'p.net_salary', 'p.status',
            ])
            ->all();

        return self::rows($rows);
    }

    /**
     * Approved slips with the banking details a transfer file needs.
     *
     * @return list<array<string, mixed>>
     */
    public function approvedForBankFile(int $tenantId, string $month, ?int $branchId = null): array
    {
        $rows = DB::table('payroll as p')
            ->join('employees as e', 'e.id', '=', 'p.employee_id')
            ->leftJoin('branches as b', 'b.id', '=', 'p.branch_id')
            ->where('p.tenant_id', $tenantId)->where('p.month', $month)->where('p.status', 'approved')
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('p.branch_id', $branchId))
            ->orderBy('e.name')
            ->get([
                'e.name as employee_name', 'e.id as employee_id', 'e.national_id', 'e.iqama_number',
                'e.nationality', 'e.bank_name', 'e.bank_account_number', 'e.bank_iban', 'e.bank_swift',
                'p.base_salary', 'p.total_bonuses', 'p.total_deductions', 'p.net_salary',
                'p.working_days', 'p.branch_id', 'b.name as branch_name',
            ])
            ->all();

        return self::rows($rows);
    }

    /**
     * @param  array<string, mixed>  $calculation
     */
    private static function encode(array $calculation): string
    {
        // Unescaped, because the breakdown is full of Arabic line labels that
        // are read straight out of this column by the payslip renderer.
        return (string) json_encode($calculation, JSON_UNESCAPED_UNICODE);
    }

    /**
     * @param  array<int, mixed>  $rows
     * @return list<array<string, mixed>>
     */
    private static function rows(array $rows): array
    {
        return array_values(array_map(self::toArray(...), $rows));
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
