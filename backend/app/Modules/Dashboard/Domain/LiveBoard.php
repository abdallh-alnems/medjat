<?php

declare(strict_types=1);

namespace App\Modules\Dashboard\Domain;

use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;

/**
 * Where everybody stands today.
 *
 * Starts from the employees rather than from the attendance rows, so somebody
 * who has not arrived still appears — a board that only lists people who
 * punched is a board that cannot show a no-show.
 *
 * One query and one derivation feed both the live screen and the dashboard
 * summary, so the two cannot disagree about who is present.
 */
final class LiveBoard
{
    /**
     * Statuses that mean the day is accounted for without anybody attending.
     *
     * @var list<string>
     */
    public const OFF_STATUSES = ['leave', 'holiday', 'weekly_off'];

    /**
     * @return list<array<string, mixed>>
     */
    public static function rows(
        int $tenantId,
        string $date,
        ?int $branchId = null,
        ?int $shiftId = null,
        ?int $categoryId = null,
    ): array {
        $rows = DB::table('employees as e')
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->leftJoin('attendance as a', function (JoinClause $join) use ($date): void {
                $join->on('a.employee_id', '=', 'e.id')
                    ->on('a.tenant_id', '=', 'e.tenant_id')
                    ->where('a.date', '=', $date);
            })
            ->leftJoin('employee_shift_schedule as sch', function (JoinClause $join) use ($date): void {
                $join->on('sch.employee_id', '=', 'e.id')
                    ->on('sch.tenant_id', '=', 'e.tenant_id')
                    ->where('sch.work_date', '=', $date);
            })
            ->leftJoin('shifts as ss', 'ss.id', '=', 'sch.shift_id')
            ->leftJoin('shifts as s', 's.id', '=', 'e.shift_id')
            ->where('e.tenant_id', $tenantId)
            ->where('e.status', 'active')
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.branch_id', $branchId))
            ->when($shiftId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.shift_id', $shiftId))
            ->when($categoryId !== null, function (QueryBuilder $q) use ($categoryId): void {
                $q->whereExists(function (QueryBuilder $inner) use ($categoryId): void {
                    $inner->select(DB::raw(1))
                        ->from('employee_category_assignments as eca')
                        ->whereColumn('eca.employee_id', 'e.id')
                        ->where('eca.category_id', $categoryId);
                });
            })
            ->orderBy('e.name')
            ->get([
                'e.id as employee_id', 'e.name', 'e.job_title', 'e.branch_id', 'b.name as branch_name',
                'a.check_in_time', 'a.check_out_time', 'a.status as attendance_status',
                'a.notes as attendance_notes', 'a.late_minutes', 'a.check_in_method', 'a.is_offline',
                // The same resolution order used everywhere else: rotating
                // schedule, then the standing shift, then the employee's own
                // hours.
                DB::raw('COALESCE(ss.start_time, s.start_time, e.work_start_time) AS shift_start'),
                DB::raw('COALESCE(ss.end_time, s.end_time, e.work_end_time) AS shift_end'),
            ])
            ->all();

        return array_values(array_map(
            static function (mixed $row): array {
                /** @var array<string, mixed> $columns */
                $columns = (array) $row;

                return $columns;
            },
            $rows,
        ));
    }

    /**
     * Whether the shift has not started yet, as opposed to a no-show.
     *
     * The distinction matters most for night shifts: at ten in the morning a
     * night worker has not failed to arrive, and flagging them would put a
     * third of the workforce on the exceptions list every day.
     */
    public static function isPreShift(?string $start, ?string $end, string $now): bool
    {
        if ($start === null) {
            return false;
        }

        // An overnight shift ends before it starts. Its "not yet" window is the
        // gap between last night's end and tonight's start, not everything
        // before the start time.
        if ($end !== null && $end <= $start) {
            return $now > $end && $now < $start;
        }

        return $now < $start;
    }
}
