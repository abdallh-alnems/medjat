<?php

/**
 * Computes the suggested end-of-service settlement figures for an employee as
 * of their last working day. Everything here is a *suggestion* — HR can edit
 * every line in the settlement page before approving. Mirrors the conventions
 * used by PayrollCalculator (daily rate = base_salary / 30).
 *
 * Gratuity uses the de-facto MENA standard tiered accrual:
 *   • 21 days of pay for each of the first 5 years of service
 *   • 30 days of pay for each year beyond 5
 * pro-rated for partial years. HR can override the days or the amount.
 */
final class SettlementCalculator {
    private const GRATUITY_DAYS_FIRST_TIER = 21; // per year, first 5 years
    private const GRATUITY_DAYS_LATER_TIER = 30; // per year, after 5 years
    private const GRATUITY_TIER_BOUNDARY   = 5;  // years

    /**
     * @param array  $employee       employee row (must include base_salary,
     *                               hire_date / contract_start, branch_id)
     * @param string $lastWorkingDay Y-m-d
     */
    public static function compute(array $employee, int $tenantId, string $lastWorkingDay): array {
        $employeeId = (int) $employee['id'];
        $baseSalary = (float) ($employee['base_salary'] ?? 0);
        $dailyRate = round($baseSalary / 30, 2);

        $hireDate = $employee['hire_date']
            ?? $employee['contract_start']
            ?? (isset($employee['created_at']) ? substr((string) $employee['created_at'], 0, 10) : null);

        $years = self::yearsOfService($hireDate, $lastWorkingDay);

        // Gratuity (end-of-service) — tiered accrual, pro-rated.
        $gratuityDays = self::gratuityDays($years);
        $gratuityAmount = round($dailyRate * $gratuityDays, 2);

        // Pending salary: what the current payroll cycle has earned up to the
        // last working day (prorated base − deductions + bonuses).
        $month = substr($lastWorkingDay, 0, 7);
        $breakdown = PayrollCalculator::calculate($employeeId, $month, $tenantId, $lastWorkingDay);
        $pendingSalary = round((float) ($breakdown['earned_to_date'] ?? 0), 2);

        // Unused annual-leave balance encashed at the daily rate.
        $year = (int) substr($lastWorkingDay, 0, 4);
        $leaveBalance = LeaveModel::getBalance($employeeId, $tenantId, $year);
        $leaveDays = (float) ($leaveBalance['remaining_days'] ?? 0);
        $leaveEncashment = round($dailyRate * $leaveDays, 2);

        // Outstanding loans / advances recovered from the settlement.
        $outstandingLoans = 0.0;
        foreach (LoanModel::getActiveSummaryForEmployee($employeeId, $tenantId) as $loan) {
            $outstandingLoans += (float) ($loan['remaining_amount'] ?? 0);
        }
        $outstandingLoans = round($outstandingLoans, 2);

        $figures = [
            'base_salary'        => $baseSalary,
            'daily_rate'         => $dailyRate,
            'hire_date'          => $hireDate,
            'years_of_service'   => $years,
            'pending_salary'     => $pendingSalary,
            'gratuity_days'      => $gratuityDays,
            'gratuity_amount'    => $gratuityAmount,
            'leave_balance_days' => $leaveDays,
            'leave_encashment'   => $leaveEncashment,
            'other_additions'    => 0.0,
            'outstanding_loans'  => $outstandingLoans,
            'other_deductions'   => 0.0,
        ];

        [$totalEarnings, $totalDeductions, $netAmount] =
            EmployeeSettlementModel::totals($figures, []);

        $figures['total_earnings'] = $totalEarnings;
        $figures['total_deductions'] = $totalDeductions;
        $figures['net_amount'] = $netAmount;

        return $figures;
    }

    /** Fractional years between hire date and last working day (min 0). */
    public static function yearsOfService(?string $hireDate, string $lastWorkingDay): float {
        if (!$hireDate) {
            return 0.0;
        }
        $start = strtotime($hireDate);
        $end = strtotime($lastWorkingDay);
        if ($start === false || $end === false || $end <= $start) {
            return 0.0;
        }
        $days = ($end - $start) / 86400;
        return round($days / 365.25, 2);
    }

    /** Tiered gratuity entitlement in days, pro-rated for partial years. */
    public static function gratuityDays(float $years): float {
        $firstTier = min($years, self::GRATUITY_TIER_BOUNDARY);
        $laterTier = max(0.0, $years - self::GRATUITY_TIER_BOUNDARY);
        $days = $firstTier * self::GRATUITY_DAYS_FIRST_TIER
            + $laterTier * self::GRATUITY_DAYS_LATER_TIER;
        return round($days, 2);
    }
}
