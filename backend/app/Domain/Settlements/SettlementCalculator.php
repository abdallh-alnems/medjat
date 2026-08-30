<?php

declare(strict_types=1);

namespace App\Domain\Settlements;

use App\Domain\Leave\LeaveBalanceCalculator;
use App\Domain\Loans\Loans;
use App\Domain\Payroll\PayrollCalculator;
use App\Models\Employee;
use App\Support\Value;
use DateTimeImmutable;

/**
 * What the company probably owes somebody on their last day.
 *
 * Every figure here is a suggestion. HR edits the settlement line by line
 * before approving it, because the things this cannot know — a disputed
 * handover, a company car, a notice period waived — are exactly the things that
 * end up on a final payment.
 *
 * Gratuity follows the de-facto MENA accrual: 21 days of pay for each of the
 * first five years, 30 for each year after, pro-rated for part years.
 */
final class SettlementCalculator
{
    private const GRATUITY_DAYS_FIRST_TIER = 21;

    private const GRATUITY_DAYS_LATER_TIER = 30;

    private const GRATUITY_TIER_BOUNDARY = 5.0;

    public function __construct(
        private readonly PayrollCalculator $payroll,
        private readonly LeaveBalanceCalculator $leave,
    ) {}

    /**
     * @return array<string, mixed>
     */
    public function compute(Employee $employee, int $tenantId, string $lastWorkingDay): array
    {
        $baseSalary = Value::float($employee->getAttribute('base_salary'));

        // Thirty, not the length of the actual month — the same convention
        // PayrollCalculator uses, so a settlement and a payslip put the same
        // price on the same day.
        $dailyRate = round($baseSalary / 30, 2);

        $hireDate = self::hireDate($employee);
        $years = self::yearsOfService($hireDate, $lastWorkingDay);
        $gratuityDays = self::gratuityDays($years);

        // What the current cycle has earned up to the last working day, rather
        // than the whole month: they are not there for the rest of it.
        $breakdown = $this->payroll->calculate(
            $employee->id, substr($lastWorkingDay, 0, 7), $tenantId, $lastWorkingDay,
        );

        $leaveDays = Value::float(
            $this->leave->forYear($employee->id, $tenantId, (int) substr($lastWorkingDay, 0, 4))['remaining_days'] ?? null
        );

        $figures = [
            'base_salary' => $baseSalary,
            'daily_rate' => $dailyRate,
            'hire_date' => $hireDate,
            'years_of_service' => $years,
            'pending_salary' => round(Value::float($breakdown['earned_to_date'] ?? null), 2),
            'gratuity_days' => $gratuityDays,
            'gratuity_amount' => round($dailyRate * $gratuityDays, 2),
            'leave_balance_days' => $leaveDays,
            'leave_encashment' => round($dailyRate * $leaveDays, 2),
            'other_additions' => 0.0,
            'outstanding_loans' => Loans::outstandingForEmployee($employee->id, $tenantId),
            'other_deductions' => 0.0,
        ];

        [$earnings, $deductions, $net] = Settlement::totals($figures, []);

        return $figures + [
            'total_earnings' => $earnings,
            'total_deductions' => $deductions,
            'net_amount' => $net,
        ];
    }

    /** Fractional years between the hire date and the last working day. */
    public static function yearsOfService(?string $hireDate, string $lastWorkingDay): float
    {
        if ($hireDate === null || $hireDate === '') {
            return 0.0;
        }

        $start = self::parse($hireDate);
        $end = self::parse($lastWorkingDay);

        if ($start === null || $end === null || $end <= $start) {
            return 0.0;
        }

        // 365.25 rather than 365: over a twenty-year service the leap days are
        // most of a week of gratuity.
        return round(($end->getTimestamp() - $start->getTimestamp()) / 86400 / 365.25, 2);
    }

    /** Tiered gratuity entitlement in days, pro-rated for part years. */
    public static function gratuityDays(float $years): float
    {
        $first = min($years, self::GRATUITY_TIER_BOUNDARY);
        $later = max(0.0, $years - self::GRATUITY_TIER_BOUNDARY);

        return round(
            $first * self::GRATUITY_DAYS_FIRST_TIER + $later * self::GRATUITY_DAYS_LATER_TIER,
            2,
        );
    }

    /**
     * The date service began.
     *
     * Falls back through contract start to the row's creation date, because a
     * missing hire date would otherwise silently price twenty years of service
     * at zero.
     */
    public static function hireDate(Employee $employee): ?string
    {
        foreach (['hire_date', 'contract_start', 'created_at'] as $column) {
            $value = Value::nullableString($employee->getAttribute($column));

            if ($value !== null && $value !== '') {
                return substr($value, 0, 10);
            }
        }

        return null;
    }

    private static function parse(string $date): ?DateTimeImmutable
    {
        $parsed = DateTimeImmutable::createFromFormat('!Y-m-d', substr($date, 0, 10));

        return $parsed === false ? null : $parsed;
    }
}
