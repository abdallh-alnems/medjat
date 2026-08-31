<?php

declare(strict_types=1);

namespace App\Modules\Reports\Domain;

use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;

/**
 * What a period of attendance looked like.
 *
 * A late arrival counts as late rather than present throughout. Folding the two
 * together would make a report where nobody is ever late, which is the one
 * thing these numbers exist to show.
 */
final class AttendanceReports
{
    /**
     * Everybody, whether or not they have any attendance in the window.
     *
     * The outer join is deliberate: somebody with no rows at all is exactly who
     * a manager opening this report is looking for.
     *
     * @return list<array<string, mixed>>
     */
    public static function byRange(int $tenantId, string $from, string $to, ?int $branchId = null): array
    {
        $rows = DB::table('employees as e')
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->leftJoin('attendance as a', function (JoinClause $join) use ($from, $to): void {
                $join->on('a.employee_id', '=', 'e.id')->whereBetween('a.date', [$from, $to]);
            })
            ->where('e.tenant_id', $tenantId)->where('e.status', '!=', 'terminated')
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.branch_id', $branchId))
            ->groupBy('e.id')
            ->orderBy('e.name')
            ->get([
                'e.id as employee_id', 'e.name as employee_name', 'e.job_title', 'b.name as branch_name',
                DB::raw("COUNT(CASE WHEN a.status = 'present' AND a.late_minutes = 0 THEN 1 END) as days_present"),
                DB::raw("COUNT(CASE WHEN a.status = 'present' AND a.late_minutes > 0 THEN 1 END) as days_late"),
                DB::raw("COUNT(CASE WHEN a.status = 'absent' THEN 1 END) as days_absent"),
                DB::raw("COUNT(CASE WHEN a.status = 'leave' THEN 1 END) as days_leave"),
                DB::raw('COUNT(a.id) as days_recorded'),
                DB::raw('COALESCE(SUM(a.worked_minutes), 0) as total_minutes_worked'),
            ])
            ->all();

        return Rows::of($rows);
    }

    /**
     * @return array<string, mixed>
     */
    public static function summary(int $tenantId, string $from, string $to, ?int $branchId = null): array
    {
        $row = DB::table('attendance as a')
            ->where('a.tenant_id', $tenantId)
            ->whereBetween('a.date', [$from, $to])
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('a.branch_id', $branchId))
            ->selectRaw(
                "COUNT(CASE WHEN a.status = 'present' AND a.late_minutes = 0 THEN 1 END) as total_present,"
                ."COUNT(CASE WHEN a.status = 'present' AND a.late_minutes > 0 THEN 1 END) as total_late,"
                ."COUNT(CASE WHEN a.status = 'absent' THEN 1 END) as total_absent,"
                ."COUNT(CASE WHEN a.status = 'leave' THEN 1 END) as total_leave,"
                .'COUNT(DISTINCT a.employee_id) as employees_with_records'
            )
            ->first();

        return $row === null ? [] : Rows::one($row);
    }

    /**
     * Overtime and lateness, per person.
     *
     * Only present days carry minutes — an absence has none — so everything is
     * scoped to them. Early departures are left out rather than shown as a
     * permanent zero: nothing writes that column.
     *
     * @return list<array<string, mixed>>
     */
    public static function overtimeAndLate(
        int $tenantId,
        string $from,
        string $to,
        ?int $branchId,
        string $sort,
    ): array {
        // Whitelisted: a client-supplied sort never reaches the SQL.
        $order = match ($sort) {
            'late' => 'late_minutes DESC, overtime_minutes DESC',
            'name' => 'e.name ASC',
            default => 'overtime_minutes DESC, late_minutes DESC',
        };

        $rows = DB::table('employees as e')
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->join('attendance as a', function (JoinClause $join) use ($from, $to): void {
                $join->on('a.employee_id', '=', 'e.id')
                    ->whereBetween('a.date', [$from, $to])
                    ->where('a.status', '=', 'present');
            })
            ->where('e.tenant_id', $tenantId)->where('e.status', '!=', 'terminated')
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.branch_id', $branchId))
            ->groupBy('e.id')
            ->havingRaw('overtime_minutes > 0 OR late_minutes > 0')
            ->orderByRaw($order)
            ->get([
                'e.id as employee_id', 'e.name as employee_name', 'e.job_title', 'b.name as branch_name',
                DB::raw('COALESCE(SUM(a.overtime_minutes), 0) as overtime_minutes'),
                DB::raw('COUNT(CASE WHEN a.overtime_minutes > 0 THEN 1 END) as overtime_days'),
                DB::raw('COALESCE(SUM(a.late_minutes), 0) as late_minutes'),
                DB::raw('COUNT(CASE WHEN a.late_minutes > 0 THEN 1 END) as late_days'),
                DB::raw('COALESCE(MAX(a.late_minutes), 0) as worst_late_minutes'),
                DB::raw('COALESCE(SUM(a.worked_minutes), 0) as worked_minutes'),
                DB::raw('COUNT(a.id) as days_present'),
            ])
            ->all();

        return Rows::of($rows);
    }

    /**
     * @return array<string, mixed>
     */
    public static function overtimeAndLateSummary(int $tenantId, string $from, string $to, ?int $branchId): array
    {
        $row = DB::table('attendance as a')
            ->join('employees as e', 'e.id', '=', 'a.employee_id')
            ->where('a.tenant_id', $tenantId)
            ->whereBetween('a.date', [$from, $to])
            ->where('a.status', 'present')
            ->where('e.status', '!=', 'terminated')
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.branch_id', $branchId))
            ->selectRaw(
                'COALESCE(SUM(a.overtime_minutes), 0) as total_overtime_minutes,'
                .'COALESCE(SUM(a.late_minutes), 0) as total_late_minutes,'
                .'COUNT(CASE WHEN a.overtime_minutes > 0 THEN 1 END) as overtime_days,'
                .'COUNT(CASE WHEN a.late_minutes > 0 THEN 1 END) as late_days,'
                .'COUNT(DISTINCT CASE WHEN a.overtime_minutes > 0 THEN a.employee_id END) as employees_with_overtime,'
                .'COUNT(DISTINCT CASE WHEN a.late_minutes > 0 THEN a.employee_id END) as employees_late'
            )
            ->first();

        return $row === null ? [] : Rows::one($row);
    }

    /**
     * The days behind one person's totals.
     *
     * Only days that carry minutes: a drill-down full of zeroes hides the ones
     * that matter.
     *
     * @return list<array<string, mixed>>
     */
    public static function overtimeAndLateDaily(int $tenantId, int $employeeId, string $from, string $to): array
    {
        $rows = DB::table('attendance as a')
            ->where('a.tenant_id', $tenantId)->where('a.employee_id', $employeeId)
            ->whereBetween('a.date', [$from, $to])
            ->where('a.status', 'present')
            ->where(fn (QueryBuilder $q): QueryBuilder => $q
                ->where('a.late_minutes', '>', 0)->orWhere('a.overtime_minutes', '>', 0))
            ->orderByDesc('a.date')
            ->limit(366)
            ->get([
                'a.date', 'a.check_in_time', 'a.check_out_time',
                'a.late_minutes', 'a.overtime_minutes', 'a.worked_minutes', 'a.notes',
            ])
            ->all();

        return Rows::of($rows);
    }
}
