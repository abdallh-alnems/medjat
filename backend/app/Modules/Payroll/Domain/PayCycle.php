<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Domain;

use App\Support\Value;
use DateTimeImmutable;
use Illuminate\Support\Facades\DB;

/**
 * The window a month's pay actually covers.
 *
 * Not every company pays by the calendar month. A cycle starting on the 26th
 * runs from the 26th of one month to the 25th of the next, and the question
 * that decides everything is which of those two months the cycle is *called*.
 */
final readonly class PayCycle
{
    private function __construct(
        public string $start,
        public string $end,
        public int $startDay,
    ) {}

    /**
     * Branch override, else the company setting, else the first of the month.
     */
    public static function resolve(int $tenantId, ?int $branchId, string $month): self
    {
        $configured = null;

        if ($branchId !== null) {
            $configured = DB::table('branches')
                ->where('id', $branchId)->where('tenant_id', $tenantId)->value('cycle_start_day');
        }

        $configured ??= DB::table('tenants')->where('id', $tenantId)->value('cycle_start_day');

        // Clamped to 28 so the anchor exists in February. A cycle starting on
        // the 30th would simply not happen in some months.
        $startDay = max(1, min(28, Value::int($configured, 1)));

        $year = (int) substr($month, 0, 4);
        $monthNumber = (int) substr($month, 5, 2);

        if ($startDay <= 1) {
            $start = sprintf('%04d-%02d-01', $year, $monthNumber);
            $lastDay = (int) date('t', (int) mktime(0, 0, 0, $monthNumber, 1, $year));

            return new self($start, sprintf('%04d-%02d-%02d', $year, $monthNumber, $lastDay), $startDay);
        }

        // Which month a straddling cycle is named after.
        //
        // A cycle starting on the 26th of March and ending on the 25th of April
        // is "April's pay" to everybody involved — most of the work happened in
        // April, and that is when it is paid. One starting on the 5th is "March"
        // for the same reason. The changeover is the middle of the month, and 17
        // is where it has been drawn: past the midpoint of the shortest month,
        // so the label follows where the bulk of the days actually fall.
        $labelledByEndMonth = $startDay >= 17;

        $anchor = new DateTimeImmutable(sprintf('%04d-%02d-%02d', $year, $monthNumber, $startDay));

        $start = $labelledByEndMonth ? $anchor->modify('-1 month') : $anchor;
        $end = $labelledByEndMonth ? $anchor->modify('-1 day') : $anchor->modify('+1 month')->modify('-1 day');

        return new self($start->format('Y-m-d'), $end->format('Y-m-d'), $startDay);
    }

    public function days(): int
    {
        return self::daysBetween($this->start, $this->end) + 1;
    }

    /**
     * Where attendance stops counting.
     *
     * A finished cycle counts in full. One still running stops at today, so a
     * live figure never charges somebody for absences on days that have not
     * happened. A cycle entirely in the future counts nothing at all — null,
     * which is different from counting a single day.
     */
    public function effectiveEnd(?string $asOf): ?string
    {
        if ($asOf === null) {
            return $this->end;
        }

        if ($asOf < $this->start) {
            return null;
        }

        return $asOf < $this->end ? $asOf : $this->end;
    }

    public function daysElapsed(?string $effectiveEnd): int
    {
        if ($effectiveEnd === null) {
            return 0;
        }

        return min($this->days(), self::daysBetween($this->start, $effectiveEnd) + 1);
    }

    public static function daysBetween(string $from, string $to): int
    {
        return (new DateTimeImmutable($from))->diff(new DateTimeImmutable($to))->days;
    }
}
