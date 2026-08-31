<?php

declare(strict_types=1);

namespace App\Modules\Schedule\Domain;

use App\Support\Value;
use DateTimeImmutable;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * The weekly rotating roster: one cell per employee per day.
 *
 * A cell with no shift is a rest day, which is not the same as an empty cell —
 * an empty one means nothing was decided and attendance falls back to the
 * employee's standing shift, while a rest day is a decision that they are off.
 *
 * Cells are drafts while a manager edits the week and only drive attendance
 * once published. Any edit knocks a cell back to draft, so a week cannot be
 * half-published: people plan their lives around this grid, and a change that
 * appeared without anyone confirming it would be worse than no roster.
 */
final class WeeklyRoster
{
    /** Saturday, the usual start of the working week in the region. */
    public const DEFAULT_WEEK_START_DAY = 6;

    /**
     * Everybody a roster can be built for.
     *
     * No pagination: the grid is only meaningful whole.
     *
     * @return list<array<string, mixed>>
     */
    public static function employees(int $tenantId, ?int $branchId = null): array
    {
        $rows = DB::table('employees as e')
            ->leftJoin('branches as b', 'b.id', '=', 'e.branch_id')
            ->where('e.tenant_id', $tenantId)
            ->whereNotIn('e.status', ['terminated', 'pending_activation'])
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.branch_id', $branchId))
            ->orderBy('e.name')
            ->get([
                'e.id', 'e.name', 'e.job_title', 'e.branch_id',
                'b.name as branch_name', 'e.shift_type', 'e.shift_id',
            ])
            ->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    /**
     * @return list<array<string, mixed>>
     */
    public static function cells(int $tenantId, string $from, string $to, ?int $branchId = null): array
    {
        $rows = DB::table('employee_shift_schedule as ess')
            ->join('employees as e', 'e.id', '=', 'ess.employee_id')
            ->leftJoin('shifts as s', 's.id', '=', 'ess.shift_id')
            ->where('ess.tenant_id', $tenantId)
            ->whereBetween('ess.work_date', [$from, $to])
            ->where('e.status', '!=', 'terminated')
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('e.branch_id', $branchId))
            ->orderBy('ess.work_date')
            ->get([
                'ess.id', 'ess.employee_id', 'ess.shift_id', 'ess.work_date', 'ess.status',
                's.name as shift_name', 's.start_time', 's.end_time',
            ])
            ->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    /**
     * Sets the same shift — or a rest day, when the shift is null — across many
     * employees and dates.
     *
     * One statement rather than a loop of round trips: a fortnight for thirty
     * people is 420 cells, and the original issued 420 queries for it.
     *
     * @param  list<int>  $employeeIds
     * @param  list<string>  $dates
     */
    public static function assign(
        int $tenantId,
        array $employeeIds,
        array $dates,
        ?int $shiftId,
        int $adminId,
    ): int {
        $rows = [];

        foreach (array_values(array_unique($employeeIds)) as $employeeId) {
            foreach ($dates as $date) {
                $rows[] = [
                    'tenant_id' => $tenantId,
                    'employee_id' => $employeeId,
                    'shift_id' => $shiftId,
                    'work_date' => $date,
                    // Any edit returns the cell to draft: it has to be
                    // republished before anybody is held to it.
                    'status' => 'draft',
                    'created_by' => $adminId,
                ];
            }
        }

        if ($rows === []) {
            return 0;
        }

        DB::table('employee_shift_schedule')->upsert(
            $rows,
            // The table's unique key, which is (employee_id, work_date) —
            // employee ids are already company-scoped.
            ['employee_id', 'work_date'],
            ['shift_id', 'status', 'created_by'],
        );

        return count($rows);
    }

    /**
     * Removes a cell entirely, which is not the same as marking a rest day —
     * attendance falls back to the employee's standing shift.
     */
    public static function clear(int $tenantId, int $employeeId, string $workDate): void
    {
        DB::table('employee_shift_schedule')
            ->where('tenant_id', $tenantId)->where('employee_id', $employeeId)->where('work_date', $workDate)
            ->delete();
    }

    /**
     * Copies one week onto another as drafts.
     *
     * The offset is whole days between the two week starts, so the shape of the
     * week is preserved: whoever was on Tuesday lands on Tuesday.
     */
    public static function copyWeek(
        int $tenantId,
        string $fromStart,
        string $toStart,
        ?int $branchId,
        int $adminId,
    ): int {
        $source = self::cells($tenantId, $fromStart, self::weekEnd($fromStart), $branchId);

        if ($source === []) {
            return 0;
        }

        $from = self::parse($fromStart);
        $to = self::parse($toStart);
        $offset = $from === null || $to === null
            ? 0
            : (int) round(($to->getTimestamp() - $from->getTimestamp()) / 86400);

        $rows = [];

        foreach ($source as $cell) {
            $rows[] = [
                'tenant_id' => $tenantId,
                'employee_id' => Value::int($cell['employee_id'] ?? null),
                'shift_id' => Value::nullableInt($cell['shift_id'] ?? null),
                'work_date' => self::shift(Value::string($cell['work_date'] ?? null), $offset),
                'status' => 'draft',
                'created_by' => $adminId,
            ];
        }

        DB::table('employee_shift_schedule')->upsert(
            $rows,
            // The table's unique key, which is (employee_id, work_date) —
            // employee ids are already company-scoped.
            ['employee_id', 'work_date'],
            ['shift_id', 'status', 'created_by'],
        );

        return count($rows);
    }

    /** Makes the week's drafts the thing attendance is judged against. */
    public static function publishWeek(int $tenantId, string $weekStart, ?int $branchId = null): int
    {
        $query = DB::table('employee_shift_schedule as ess')
            ->where('ess.tenant_id', $tenantId)
            ->whereBetween('ess.work_date', [$weekStart, self::weekEnd($weekStart)])
            ->where('ess.status', 'draft');

        if ($branchId !== null) {
            $query->join('employees as e', 'e.id', '=', 'ess.employee_id')->where('e.branch_id', $branchId);
        }

        return $query->update(['ess.status' => 'published']);
    }

    /**
     * Snaps a date back to the start of its roster week.
     *
     * The week starts on whichever weekday the company chose, so the grid lines
     * up with how they actually think about a week rather than with ISO.
     */
    public static function snapToWeekStart(string $date, int $weekStartDay): string
    {
        $parsed = self::parse($date);

        if ($parsed === null) {
            return $date;
        }

        $back = ((int) $parsed->format('N') - $weekStartDay + 7) % 7;

        return $parsed->modify("-{$back} days")->format('Y-m-d');
    }

    /**
     * The company's chosen first day of the week, 1 = Monday … 7 = Sunday.
     */
    public static function weekStartDay(int $tenantId): int
    {
        $configured = Value::int(
            DB::table('tenants')->where('id', $tenantId)->value('week_start_day'),
            self::DEFAULT_WEEK_START_DAY,
        );

        return $configured >= 1 && $configured <= 7 ? $configured : self::DEFAULT_WEEK_START_DAY;
    }

    /**
     * The seven dates of the week beginning here.
     *
     * @return list<string>
     */
    public static function days(string $weekStart): array
    {
        return array_map(static fn (int $offset): string => self::shift($weekStart, $offset), range(0, 6));
    }

    public static function weekEnd(string $weekStart): string
    {
        return self::shift($weekStart, 6);
    }

    private static function shift(string $date, int $days): string
    {
        $parsed = self::parse($date);

        if ($parsed === null) {
            return $date;
        }

        return $parsed->modify(($days >= 0 ? '+' : '-').abs($days).' days')->format('Y-m-d');
    }

    private static function parse(string $date): ?DateTimeImmutable
    {
        $parsed = DateTimeImmutable::createFromFormat('!Y-m-d', substr($date, 0, 10));

        return $parsed === false ? null : $parsed;
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
