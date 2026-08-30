<?php

declare(strict_types=1);

namespace App\Modules\Employees\Services;

use App\Modules\Attendance\Domain\AbsenceBackfill;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use DateInterval;
use DatePeriod;
use DateTimeImmutable;
use Illuminate\Support\Facades\DB;

/**
 * One row per day between two dates, with no gaps.
 *
 * A calendar with holes is unreadable: the eye cannot tell a day nobody worked
 * from a day nobody recorded. So every date in the range gets a row, and days
 * with no attendance record are given the status they actually had — a public
 * holiday, a weekly day off, approved leave, an absence, or simply not arrived
 * yet on a day that is still running.
 */
final class AttendanceCalendar
{
    /**
     * @return list<array<string, mixed>>
     */
    public function build(int $employeeId, int $tenantId, string $from, string $to): array
    {
        $recorded = DB::table('attendance')
            ->where('employee_id', $employeeId)
            ->where('tenant_id', $tenantId)
            ->whereBetween('date', [$from, $to])
            ->get()
            ->keyBy(static fn (object $row): string => Value::string($row->date));

        $onLeave = DB::table('leaves')
            ->where('employee_id', $employeeId)
            ->where('tenant_id', $tenantId)
            ->where('status', 'approved')
            ->whereBetween('date', [$from, $to])
            ->pluck('type', 'date');

        $holidays = DB::table('holidays')
            ->where('tenant_id', $tenantId)
            ->whereBetween('date', [$from, $to])
            ->pluck('date')
            ->map(static fn (mixed $d): string => Value::string($d))
            ->flip();

        $weeklyOff = $this->weeklyOffDays($employeeId, $tenantId);
        $today = TenantClock::date($tenantId);

        $days = [];

        $period = new DatePeriod(
            new DateTimeImmutable($from),
            new DateInterval('P1D'),
            (new DateTimeImmutable($to))->modify('+1 day'),
        );

        foreach ($period as $day) {
            $date = $day->format('Y-m-d');
            $weekday = mb_strtolower($day->format('l'));

            $row = $recorded->get($date);

            if ($row !== null) {
                /** @var array<string, mixed> $recordedDay */
                $recordedDay = (array) $row;
                $days[] = $recordedDay;

                continue;
            }

            $days[] = [
                'date' => $date,
                'status' => $this->statusFor($date, $weekday, $today, $onLeave, $holidays, $weeklyOff),
                'check_in_time' => null,
                'check_out_time' => null,
                'worked_minutes' => 0,
                'overtime_minutes' => 0,
                'late_minutes' => 0,
                'leave_type' => $onLeave[$date] ?? null,
            ];
        }

        return $days;
    }

    /**
     * @param  \Illuminate\Support\Collection<array-key, mixed>  $onLeave
     * @param  \Illuminate\Support\Collection<string, int>  $holidays
     * @param  list<string>  $weeklyOff
     */
    private function statusFor(
        string $date,
        string $weekday,
        string $today,
        \Illuminate\Support\Collection $onLeave,
        \Illuminate\Support\Collection $holidays,
        array $weeklyOff,
    ): string {
        // Order matters: leave outranks a holiday, which outranks a weekly day
        // off, because that is the order somebody would explain the day in.
        if ($onLeave->has($date)) {
            return 'leave';
        }

        if ($holidays->has($date)) {
            return 'holiday';
        }

        if (in_array($weekday, $weeklyOff, true)) {
            return 'weekly_off';
        }

        // A day that has not finished is "not arrived", not "absent". Calling
        // somebody absent at nine in the morning is simply wrong.
        return $date >= $today ? 'not_arrived' : 'absent';
    }

    /**
     * @return list<string>
     */
    private function weeklyOffDays(int $employeeId, int $tenantId): array
    {
        $stored = Value::string(
            DB::table('employees')->where('id', $employeeId)->where('tenant_id', $tenantId)->value('weekly_off_days')
        );

        if ($stored === '') {
            return [];
        }

        return array_values(array_map('trim', explode(',', $stored)));
    }

    /**
     * Materialises pending absences so payroll and the reports stay in step.
     *
     * The calendar above renders correct statuses regardless; this is about the
     * rest of the system agreeing with it. Best-effort, and never allowed to
     * block the view.
     */
    public function catchUpAbsences(int $tenantId, string $from, string $to): void
    {
        $today = TenantClock::date($tenantId);
        $end = min($to, date('Y-m-d', (int) strtotime($today.' -1 day')));

        if ($end < $from) {
            return;
        }

        $period = new DatePeriod(
            new DateTimeImmutable($from),
            new DateInterval('P1D'),
            (new DateTimeImmutable($end))->modify('+1 day'),
        );

        foreach ($period as $day) {
            AbsenceBackfill::run($tenantId, $day->format('Y-m-d'));
        }
    }
}
