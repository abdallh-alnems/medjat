<?php

declare(strict_types=1);

namespace App\Modules\Breaks\Domain;

use App\Shared\Time\TenantClock;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * Short permissions to be away during a shift.
 *
 * A request has a window, and the window is what makes this different from
 * leave: once it has passed there is nothing left to decide. Pending requests
 * whose time is gone are swept to cancelled before any list is shown, so a
 * manager is never offered a decision that cannot mean anything.
 *
 * Every comparison against "now" here goes through the company's clock. The
 * original mixed the two — the sweep used the database's NOW() while the
 * endpoint guards used PHP's, which runs UTC — so a window looked open for
 * three hours after it closed, and the two disagreed about which.
 */
final class BreakRequests
{
    /** Longer than this is not a permission, it is a day off. */
    public const MAX_DURATION_MINUTES = 480;

    public const STATUSES = ['pending', 'approved', 'rejected', 'postponed', 'cancelled'];

    public function create(
        int $tenantId,
        int $employeeId,
        string $date,
        string $startTime,
        string $endTime,
        int $durationMinutes,
        string $type,
        ?string $reason,
        bool $deductFromSalary,
    ): int {
        return (int) DB::table('break_requests')->insertGetId([
            'tenant_id' => $tenantId,
            'employee_id' => $employeeId,
            'date' => $date,
            'start_time' => $startTime,
            'end_time' => $endTime,
            'duration_minutes' => $durationMinutes,
            'type' => $type,
            'deduct_from_salary' => $deductFromSalary ? 1 : 0,
            'reason' => $reason,
            'status' => 'pending',
        ]);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function find(int $id, int $tenantId): ?array
    {
        $row = DB::table('break_requests')->where('id', $id)->where('tenant_id', $tenantId)->first();

        return $row === null ? null : self::toArray($row);
    }

    public function approve(int $id, int $tenantId, int $adminId, ?string $note, bool $deductFromSalary): bool
    {
        return DB::table('break_requests')
            ->where('id', $id)->where('tenant_id', $tenantId)->where('status', 'pending')
            ->update([
                'status' => 'approved',
                'decided_by' => $adminId,
                'decided_at' => DB::raw('NOW()'),
                'decision_note' => $note,
                'deduct_from_salary' => $deductFromSalary ? 1 : 0,
            ]) > 0;
    }

    public function reject(int $id, int $tenantId, int $adminId, ?string $note): bool
    {
        return DB::table('break_requests')
            ->where('id', $id)->where('tenant_id', $tenantId)->where('status', 'pending')
            ->update([
                'status' => 'rejected',
                'decided_by' => $adminId,
                'decided_at' => DB::raw('NOW()'),
                'decision_note' => $note,
            ]) > 0;
    }

    /**
     * A manager offering a different time instead of refusing outright.
     *
     * The suggestion sits beside the original rather than replacing it, so the
     * employee can see what they asked for and what is being offered.
     */
    public function postpone(
        int $id,
        int $tenantId,
        int $adminId,
        ?string $note,
        ?string $date,
        ?string $startTime,
        ?string $endTime,
    ): bool {
        return DB::table('break_requests')
            ->where('id', $id)->where('tenant_id', $tenantId)->where('status', 'pending')
            ->update([
                'status' => 'postponed',
                'decided_by' => $adminId,
                'decided_at' => DB::raw('NOW()'),
                'decision_note' => $note,
                'suggested_date' => $date,
                'suggested_start_time' => $startTime,
                'suggested_end_time' => $endTime,
            ]) > 0;
    }

    /**
     * The employee takes the offered slot: the request adopts it and is
     * approved. The suggestion columns are cleared, because once adopted they
     * are the request rather than a proposal about it.
     */
    public function acceptPostpone(int $id, int $employeeId, int $tenantId, int $durationMinutes): bool
    {
        return DB::table('break_requests')
            ->where('id', $id)->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->where('status', 'postponed')->whereNotNull('suggested_date')
            ->update([
                'date' => DB::raw('suggested_date'),
                'start_time' => DB::raw('suggested_start_time'),
                'end_time' => DB::raw('suggested_end_time'),
                'duration_minutes' => $durationMinutes,
                'status' => 'approved',
                'decided_at' => DB::raw('NOW()'),
                'suggested_date' => null,
                'suggested_start_time' => null,
                'suggested_end_time' => null,
            ]) > 0;
    }

    public function rejectPostpone(int $id, int $employeeId, int $tenantId): bool
    {
        return DB::table('break_requests')
            ->where('id', $id)->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->where('status', 'postponed')
            ->update([
                'status' => 'cancelled',
                'decision_note' => 'رفض الموظف الوقت البديل المقترح',
            ]) > 0;
    }

    public function cancel(int $id, int $employeeId, int $tenantId): bool
    {
        return DB::table('break_requests')
            ->where('id', $id)->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->where('status', 'pending')
            ->update(['status' => 'cancelled']) > 0;
    }

    /**
     * Cancels pending requests whose window has already closed.
     *
     * A request cannot stay pending once its time is gone, and a manager should
     * not be shown a decision that could only be made retroactively.
     */
    public function expirePastPending(int $tenantId, ?int $employeeId = null): int
    {
        return DB::table('break_requests')
            ->where('tenant_id', $tenantId)
            ->where('status', 'pending')
            ->whereRaw('TIMESTAMP(`date`, end_time) < ?', [TenantClock::timestamp($tenantId)])
            ->when($employeeId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('employee_id', $employeeId))
            ->update([
                'status' => 'cancelled',
                'decision_note' => 'انتهى وقت الإذن قبل البتّ فيه',
            ]);
    }

    /**
     * Two windows on the same day that touch.
     *
     * Approved and pending both count: two overlapping requests waiting on a
     * manager is a mess somebody has to untangle by hand.
     */
    public function overlaps(
        int $employeeId,
        int $tenantId,
        string $date,
        string $start,
        string $end,
        ?int $excludeId = null,
    ): bool {
        return DB::table('break_requests')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)->where('date', $date)
            ->whereIn('status', ['pending', 'approved'])
            ->where('start_time', '<', $end)
            ->where('end_time', '>', $start)
            ->when($excludeId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('id', '!=', $excludeId))
            ->exists();
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function forEmployee(int $employeeId, int $tenantId, ?string $status = null): array
    {
        $rows = DB::table('break_requests')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->when($status !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('status', $status))
            ->orderByDesc('date')->orderByDesc('start_time')
            ->get()->all();

        return self::rows($rows);
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function forManager(
        int $tenantId,
        ?int $branchId = null,
        ?string $status = null,
        ?string $from = null,
        ?string $to = null,
        ?int $categoryId = null,
        ?string $search = null,
    ): array {
        $rows = DB::table('break_requests as br')
            ->join('employees as e', 'e.id', '=', 'br.employee_id')
            ->leftJoin('admins as a', 'a.id', '=', 'br.decided_by')
            ->where('br.tenant_id', $tenantId)
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.branch_id', $branchId))
            ->when($categoryId !== null, fn (QueryBuilder $q): QueryBuilder => $q->whereExists(
                fn (QueryBuilder $sub): QueryBuilder => $sub->from('employee_category_assignments as eca')
                    ->whereColumn('eca.employee_id', 'e.id')
                    ->where('eca.category_id', $categoryId)
            ))
            ->when($search !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.name', 'like', '%'.$search.'%'))
            ->when($status !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('br.status', $status))
            ->when($from !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('br.date', '>=', $from))
            ->when($to !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('br.date', '<=', $to))
            ->orderByDesc('br.date')->orderByDesc('br.start_time')
            ->get(['br.*', 'e.name as employee_name', 'e.branch_id', 'a.name as decided_by_name'])
            ->all();

        return self::rows($rows);
    }

    /**
     * Whether the window has already closed, by the company's clock.
     */
    public static function windowHasPassed(int $tenantId, string $date, string $endTime): bool
    {
        return $date.' '.$endTime < TenantClock::timestamp($tenantId);
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
