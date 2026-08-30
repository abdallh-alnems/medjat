<?php

declare(strict_types=1);

namespace App\Domain\Reports;

use App\Domain\Time\TenantClock;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;

/**
 * Who works here, and what leave they have taken.
 *
 * Terminated staff are excluded everywhere: a headcount, a salary total and a
 * branch count are all present-tense questions, and including former staff
 * would make each of them wrong in a different way.
 */
final class StaffReports
{
    /**
     * The roster, with this month's attendance beside each person.
     *
     * @return list<array<string, mixed>>
     */
    public static function employees(int $tenantId, ?int $branchId = null): array
    {
        // The company's month, not the server's: a report opened at 01:00 in
        // Cairo on the first should show the new month, not the old one.
        $month = substr(TenantClock::date($tenantId), 0, 7);

        $rows = DB::table('employees as e')
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->leftJoin('shifts as s', 's.id', '=', 'e.shift_id')
            ->leftJoin('attendance as a', function (JoinClause $join) use ($month): void {
                $join->on('a.employee_id', '=', 'e.id')
                    ->whereRaw("DATE_FORMAT(a.date, '%Y-%m') = ?", [$month]);
            })
            ->where('e.tenant_id', $tenantId)->where('e.status', '!=', 'terminated')
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.branch_id', $branchId))
            ->groupBy('e.id')
            ->orderBy('e.name')
            ->get([
                'e.id as employee_id', 'e.name as employee_name', 'e.job_title', 'e.phone',
                'e.base_salary', 'e.hire_date', 'e.status',
                'b.name as branch_name', 's.name as shift_name',
                DB::raw("COALESCE(SUM(CASE WHEN a.status = 'present' AND a.late_minutes = 0 THEN 1 END), 0) as days_present"),
                DB::raw("COALESCE(SUM(CASE WHEN a.status = 'present' AND a.late_minutes > 0 THEN 1 END), 0) as days_late"),
                DB::raw("COALESCE(SUM(CASE WHEN a.status = 'absent' THEN 1 END), 0) as days_absent"),
                DB::raw("COALESCE(SUM(CASE WHEN a.status = 'leave' THEN 1 END), 0) as days_leave"),
                DB::raw('COALESCE(SUM(a.worked_minutes), 0) as total_minutes_worked'),
            ])
            ->all();

        return array_map(
            static fn (array $row): array => $row + ['current_month' => $month],
            Rows::of($rows),
        );
    }

    /**
     * @return array<string, mixed>
     */
    public static function employeeSummary(int $tenantId, ?int $branchId = null): array
    {
        $row = DB::table('employees')
            ->where('tenant_id', $tenantId)->where('status', '!=', 'terminated')
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('branch_id', $branchId))
            ->selectRaw(
                'COUNT(*) as total_employees,'
                ."COUNT(CASE WHEN status = 'active' THEN 1 END) as active_count,"
                ."COUNT(CASE WHEN status = 'on_leave' THEN 1 END) as on_leave_count,"
                ."COUNT(CASE WHEN status = 'pending_activation' THEN 1 END) as pending_count,"
                ."COUNT(CASE WHEN status = 'suspended' THEN 1 END) as suspended_count,"
                .'COALESCE(SUM(base_salary), 0) as total_salaries,'
                .'COUNT(DISTINCT branch_id) as branch_count'
            )
            ->first();

        return $row === null ? [] : Rows::one($row);
    }

    /**
     * @return list<array<string, mixed>>
     */
    public static function leaves(
        int $tenantId,
        string $from,
        string $to,
        ?int $branchId = null,
        ?string $status = null,
    ): array {
        $rows = DB::table('leaves as l')
            ->join('employees as e', 'e.id', '=', 'l.employee_id')
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->where('l.tenant_id', $tenantId)
            ->whereBetween('l.date', [$from, $to])
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.branch_id', $branchId))
            ->when($status !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('l.status', $status))
            ->orderByDesc('l.date')
            ->get([
                'l.id', 'l.employee_id', 'e.name as employee_name', 'b.name as branch_name',
                'l.type', 'l.start_date', 'l.end_date', 'l.reason', 'l.status', 'l.created_at',
            ])
            ->all();

        return Rows::of($rows);
    }

    /**
     * @return array<string, mixed>
     */
    public static function leaveSummary(int $tenantId, string $from, string $to, ?int $branchId = null): array
    {
        $row = DB::table('leaves')
            ->where('tenant_id', $tenantId)
            ->whereBetween('date', [$from, $to])
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->whereIn(
                'employee_id',
                fn (QueryBuilder $sub): QueryBuilder => $sub->from('employees')->select('id')->where('branch_id', $branchId)
            ))
            ->selectRaw(
                'COUNT(*) as total_leaves,'
                ."COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_count,"
                ."COUNT(CASE WHEN status = 'approved' THEN 1 END) as approved_count,"
                ."COUNT(CASE WHEN status = 'rejected' THEN 1 END) as rejected_count,"
                ."COUNT(CASE WHEN type = 'annual' THEN 1 END) as annual_count,"
                ."COUNT(CASE WHEN type = 'sick' THEN 1 END) as sick_count,"
                ."COUNT(CASE WHEN type = 'personal' THEN 1 END) as personal_count,"
                ."COUNT(CASE WHEN type = 'unpaid' THEN 1 END) as unpaid_count,"
                .'COUNT(DISTINCT employee_id) as employees_on_leave'
            )
            ->first();

        return $row === null ? [] : Rows::one($row);
    }
}
