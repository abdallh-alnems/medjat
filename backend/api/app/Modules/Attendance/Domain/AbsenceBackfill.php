<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Domain;

use App\Modules\Leave\Domain\LeaveRequests;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;

/**
 * Writes the 'absent' rows for a day nobody showed up on.
 *
 * Absence is the one attendance state with no event behind it, so it has to be
 * inferred — and inferred carefully, because every exemption missed here marks
 * somebody absent who was legitimately away. Approved leave, a public holiday, a
 * recurring closure, a weekly day off and a published rest day each stop it.
 *
 * Idempotent by construction (INSERT IGNORE on the one-per-day key), so running
 * it on every view of a past day is safe.
 */
final class AbsenceBackfill
{
    /**
     * @param  string|null  $nowTime  Wall-clock time when filling in the day
     *                                that is still in progress. Absence is only
     *                                confirmed once the shift has ended;
     *                                before that the person is merely not here
     *                                yet.
     * @return int Rows written.
     */
    public static function run(int $tenantId, string $date, ?string $nowTime = null): int
    {
        $weekday = strtolower(date('l', (int) strtotime($date)));

        $candidates = DB::table('employees as e')
            ->leftJoin('employee_shift_schedule as sch', function (JoinClause $join) use ($date): void {
                $join->on('sch.employee_id', '=', 'e.id')
                    ->on('sch.tenant_id', '=', 'e.tenant_id')
                    ->where('sch.work_date', '=', $date);
            })
            ->leftJoin('shifts as s', 's.id', '=', DB::raw('COALESCE(sch.shift_id, e.shift_id)'))
            ->where('e.tenant_id', $tenantId)
            ->where('e.status', 'active')
            ->whereNotExists(function (QueryBuilder $query) use ($date): void {
                $query->select(DB::raw(1))
                    ->from('attendance as a')
                    ->whereColumn('a.employee_id', 'e.id')
                    ->whereColumn('a.tenant_id', 'e.tenant_id')
                    ->where('a.date', $date);
            })
            ->get([
                'e.id', 'e.branch_id', 'e.weekly_off_days', 'e.work_end_time',
                'sch.id as sched_id', 'sch.shift_id as sched_shift_id',
                's.start_time as shift_start', 's.end_time as shift_end',
            ]);

        if ($candidates->isEmpty()) {
            return 0;
        }

        // Matched against the leave's whole range. The `date` column holds only
        // the start of the request, so matching on it wrote an absence for
        // every day of an approved week off except the first.
        $onLeave = LeaveRequests::employeesOnLeave($tenantId, $date);

        [$holidayEverywhere, $holidayBranches] = self::scope(
            DB::table('holidays')->where('tenant_id', $tenantId)->where('date', $date)->pluck('branch_id')->values()->all()
        );

        [$closedEverywhere, $closedBranches] = self::scope(
            DB::table('recurring_leaves')
                ->where('tenant_id', $tenantId)->where('day_of_week', $weekday)->where('is_active', 1)
                ->pluck('branch_id')->values()->all()
        );

        $written = 0;

        foreach ($candidates as $employee) {
            $employeeId = Value::int($employee->id);
            $branchId = Value::nullableInt($employee->branch_id);

            if (isset($onLeave[$employeeId])) {
                continue;
            }

            if (self::isWeeklyOff(Value::string($employee->weekly_off_days), $weekday)) {
                continue;
            }

            if ($holidayEverywhere || ($branchId !== null && isset($holidayBranches[$branchId]))) {
                continue;
            }

            if ($closedEverywhere || ($branchId !== null && isset($closedBranches[$branchId]))) {
                continue;
            }

            // A published cell naming no shift is an explicit rest day.
            if ($employee->sched_id !== null && $employee->sched_shift_id === null) {
                continue;
            }

            if ($nowTime !== null && ! self::shiftHasEnded($employee, $nowTime)) {
                continue;
            }

            DB::insert(
                "INSERT IGNORE INTO attendance (tenant_id, branch_id, employee_id, date, status)
                 VALUES (?, ?, ?, ?, 'absent')",
                [$tenantId, $branchId, $employeeId, $date]
            );
            $written++;
        }

        return $written;
    }

    private static function isWeeklyOff(string $weeklyOffDays, string $weekday): bool
    {
        if ($weeklyOffDays === '') {
            return false;
        }

        return in_array($weekday, array_map('trim', explode(',', $weeklyOffDays)), true);
    }

    /**
     * A row with a null branch applies to the whole company; the rest apply to
     * the branches they name.
     *
     * @param  array<int, mixed>  $branchIds
     * @return array{bool, array<int, true>}
     */
    private static function scope(array $branchIds): array
    {
        $everywhere = false;
        $branches = [];

        foreach ($branchIds as $branchId) {
            if ($branchId === null) {
                $everywhere = true;

                continue;
            }
            $branches[Value::int($branchId)] = true;
        }

        return [$everywhere, $branches];
    }

    /**
     * For the day still in progress, absence is only confirmed once the shift is
     * over. An overnight shift ends tomorrow, so it is deferred rather than
     * guessed at.
     */
    private static function shiftHasEnded(object $employee, string $nowTime): bool
    {
        $end = Value::nullableString($employee->shift_end ?? null)
            ?? Value::nullableString($employee->work_end_time ?? null);
        $start = Value::nullableString($employee->shift_start ?? null);

        if ($end === null) {
            return false;
        }

        if ($start !== null && $end <= $start) {
            return false;
        }

        return $nowTime >= $end;
    }
}
