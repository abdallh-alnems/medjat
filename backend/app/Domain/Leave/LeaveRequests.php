<?php

declare(strict_types=1);

namespace App\Domain\Leave;

use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * Leave requests: recording them, deciding them, reading them back.
 *
 * A leave carries both a `date` and a `start_date`/`end_date` range. The single
 * date is what the attendance side matches a day against; the range is what the
 * balance counts. They are written together and must stay in step, which is why
 * nothing outside this class writes the table.
 */
final class LeaveRequests
{
    public const TYPES = ['annual', 'sick', 'personal', 'unpaid'];

    /** How many decisions one person may have outstanding at a time. */
    public const PENDING_LIMIT = 2;

    /**
     * Everybody on approved leave on a given day.
     *
     * Matched against the range, not the `date` column. `date` holds the start
     * of the request, so matching on it recognises only the first day of a
     * week off: the original did that in both the dashboard and the absence
     * backfill, which meant an approved five-day leave produced four 'absent'
     * rows — and, through the deduction rules, four days of docked pay against
     * somebody whose balance had already been debited for them.
     *
     * @return array<int, true>
     */
    public static function employeesOnLeave(int $tenantId, string $date): array
    {
        $ids = DB::table('leaves')
            ->where('tenant_id', $tenantId)
            ->where('status', 'approved')
            ->whereDate('start_date', '<=', $date)
            ->whereDate('end_date', '>=', $date)
            ->pluck('employee_id')
            ->all();

        /** @var array<int, true> $flags */
        $flags = [];

        foreach ($ids as $id) {
            $flags[Value::int($id)] = true;
        }

        return $flags;
    }

    /**
     * Why somebody is off, for the board: their own words if they gave any,
     * otherwise the leave type.
     */
    public static function reasonOn(int $employeeId, int $tenantId, string $date): ?string
    {
        $row = DB::table('leaves')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->where('status', 'approved')
            ->whereDate('start_date', '<=', $date)
            ->whereDate('end_date', '>=', $date)
            ->first(['type', 'reason']);

        if ($row === null) {
            return null;
        }

        $reason = trim(Value::string($row->reason));

        return $reason !== '' ? $reason : Value::nullableString($row->type);
    }

    public function open(
        int $employeeId,
        int $tenantId,
        string $type,
        string $startDate,
        string $endDate,
        ?string $reason = null,
    ): int {
        return (int) DB::table('leaves')->insertGetId([
            'tenant_id' => $tenantId,
            'employee_id' => $employeeId,
            'date' => $startDate,
            'start_date' => $startDate,
            'end_date' => $endDate,
            'type' => $type,
            'reason' => $reason,
            'status' => 'pending',
        ]);
    }

    public function approve(int $leaveId, int $tenantId, int $adminId): void
    {
        DB::table('leaves')->where('id', $leaveId)->where('tenant_id', $tenantId)->update([
            'status' => 'approved',
            'approved_by' => $adminId,
            'approved_at' => DB::raw('NOW()'),
        ]);
    }

    public function reject(int $leaveId, int $tenantId, int $adminId, ?string $reason = null): void
    {
        DB::table('leaves')->where('id', $leaveId)->where('tenant_id', $tenantId)->update([
            'status' => 'rejected',
            'rejected_by' => $adminId,
            'rejection_reason' => $reason,
        ]);
    }

    /**
     * Does this period run into one the employee already has?
     *
     * Pending requests count as well as approved ones — two overlapping
     * requests waiting on a manager is a mess somebody has to untangle by hand.
     */
    public function overlaps(int $employeeId, int $tenantId, string $start, string $end, ?int $excludeId = null): bool
    {
        return DB::table('leaves')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->whereIn('status', ['approved', 'pending'])
            ->where('start_date', '<=', $end)
            ->where('end_date', '>=', $start)
            ->when($excludeId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('id', '!=', $excludeId))
            ->exists();
    }

    public function pendingCount(int $employeeId, int $tenantId): int
    {
        return DB::table('leaves')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->where('status', 'pending')
            ->count();
    }

    /**
     * A request the employee owns and that nobody has decided yet — the only
     * kind they may change or withdraw themselves.
     *
     * @return array<string, mixed>|null
     */
    public function ownedPending(int $leaveId, int $employeeId, int $tenantId): ?array
    {
        $row = DB::table('leaves')
            ->where('id', $leaveId)->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->where('status', 'pending')
            ->first([
                'id', 'employee_id', 'type', 'reason', 'status',
                DB::raw("DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date"),
                DB::raw("DATE_FORMAT(end_date, '%Y-%m-%d') AS end_date"),
            ]);

        return $row === null ? null : self::toArray($row);
    }

    public function withdrawOwn(int $leaveId, int $employeeId, int $tenantId): bool
    {
        return DB::table('leaves')
            ->where('id', $leaveId)->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->where('status', 'pending')
            ->delete() > 0;
    }

    public function amendOwn(
        int $leaveId,
        int $employeeId,
        int $tenantId,
        string $type,
        string $startDate,
        string $endDate,
        ?string $reason,
    ): bool {
        return DB::table('leaves')
            ->where('id', $leaveId)->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->where('status', 'pending')
            ->update([
                'type' => $type,
                'date' => $startDate,
                'start_date' => $startDate,
                'end_date' => $endDate,
                'reason' => $reason,
            ]) > 0;
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function forEmployee(int $employeeId, int $tenantId, ?string $status = null, int $limit = 50): array
    {
        $rows = DB::table('leaves')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->when($status !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('status', $status))
            ->orderByDesc('created_at')->orderByDesc('id')
            ->limit($limit)
            ->get([
                'id', 'type', 'reason', 'status', 'rejection_reason',
                DB::raw("DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date"),
                DB::raw("DATE_FORMAT(end_date, '%Y-%m-%d') AS end_date"),
                DB::raw('(DATEDIFF(end_date, start_date) + 1) AS days'),
                DB::raw("DATE_FORMAT(created_at, '%Y-%m-%d') AS created_at"),
            ])
            ->all();

        return self::rows($rows);
    }

    /**
     * The management list, with the names behind every id so the screen does
     * not have to ask again per row.
     *
     * @return array{items: list<array<string, mixed>>, page: int}
     */
    public function forTenant(
        int $tenantId,
        int $page,
        int $limit,
        ?string $status = null,
        ?int $branchId = null,
        ?int $categoryId = null,
        ?string $search = null,
    ): array {
        $rows = DB::table('leaves as l')
            ->join('employees as e', 'e.id', '=', 'l.employee_id')
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->leftJoin('admins as ap', 'ap.id', '=', 'l.approved_by')
            ->leftJoin('admins as rj', 'rj.id', '=', 'l.rejected_by')
            ->where('l.tenant_id', $tenantId)
            ->when($status !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('l.status', $status))
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.branch_id', $branchId))
            ->when($categoryId !== null, fn (QueryBuilder $q): QueryBuilder => $q->whereExists(
                fn (QueryBuilder $sub): QueryBuilder => $sub->from('employee_category_assignments as eca')
                    ->whereColumn('eca.employee_id', 'e.id')
                    ->where('eca.category_id', $categoryId)
            ))
            ->when($search !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.name', 'like', '%'.$search.'%'))
            ->orderByDesc('l.created_at')
            ->limit($limit)->offset(($page - 1) * $limit)
            ->get([
                'l.*', 'e.name as employee_name', 'e.branch_id', 'b.name as branch_name',
                'ap.name as approved_by_name', 'rj.name as rejected_by_name',
                DB::raw('(SELECT GROUP_CONCAT(eca.category_id) FROM employee_category_assignments eca WHERE eca.employee_id = e.id) AS category_ids'),
            ])
            ->all();

        return ['items' => self::rows($rows), 'page' => $page];
    }

    /**
     * Inclusive: a single-day leave is one day, not zero.
     */
    public static function days(string $start, string $end): int
    {
        $from = strtotime($start);
        $to = strtotime($end);

        if ($from === false || $to === false) {
            return 0;
        }

        return (int) round(($to - $from) / 86400) + 1;
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
