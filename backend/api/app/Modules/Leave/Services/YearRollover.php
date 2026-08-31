<?php

declare(strict_types=1);

namespace App\Modules\Leave\Services;

use App\Exceptions\ApiFailure;
use App\Modules\Leave\Domain\CarryoverPolicy;
use App\Modules\Leave\Domain\LeaveBalanceCalculator;
use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * Closing one leave year and opening the next.
 *
 * Each employee's remaining days are split three ways: carried into the new
 * year up to the policy's cap, cashed out if the policy says so, and otherwise
 * dropped. The one thing that must not happen is a statutory minimum quietly
 * disappearing, so where a legal floor is set, days that would have been lost
 * are rescued as cash instead.
 *
 * The whole run is one transaction. A half-applied rollover would leave some
 * employees with a new-year balance and others without, and there is no way to
 * tell afterwards which is which.
 */
final class YearRollover
{
    public function __construct(private readonly LeaveBalanceCalculator $balances) {}

    /**
     * @return array{from_year: int, to_year: int, processed: int, total_carried: int, total_encashed: int, total_dropped: int}
     */
    public function run(int $tenantId, int $fromYear): array
    {
        $defaultEntitlement = DB::table('tenants')->where('id', $tenantId)->value('default_annual_leave_days');

        if ($defaultEntitlement === null && ! DB::table('tenants')->where('id', $tenantId)->exists()) {
            throw new ApiFailure(__('messages.tenant_not_found'), 404, 'not_found');
        }

        $toYear = $fromYear + 1;
        $default = Value::int($defaultEntitlement);

        $employees = DB::table('employees')
            ->where('tenant_id', $tenantId)
            ->where('status', '!=', 'terminated')
            ->get(['id', 'annual_leave_days', 'base_salary']);

        return DB::transaction(function () use ($employees, $tenantId, $fromYear, $toYear, $default): array {
            $processed = 0;
            $totalCarried = 0;
            $totalEncashed = 0;
            $totalDropped = 0;

            foreach ($employees as $employee) {
                $employeeId = Value::int($employee->id);
                $remaining = Value::int($this->balances->forYear($employeeId, $tenantId, $fromYear)['remaining_days']);
                $policy = CarryoverPolicy::resolve($employeeId, $tenantId);

                $carried = $policy->enabled
                    ? ($policy->maxDays === null ? $remaining : min($remaining, $policy->maxDays))
                    : 0;

                $encashed = $policy->encashExcess ? $remaining - $carried : 0;

                if ($policy->legalMinCarryDays !== null) {
                    // Only up to what the employee actually had: the floor
                    // protects days they earned, it does not invent new ones.
                    $mustSurvive = min($policy->legalMinCarryDays, $remaining);
                    $shortfall = $mustSurvive - ($carried + $encashed);

                    if ($shortfall > 0) {
                        $encashed += $shortfall;
                    }
                }

                $dropped = $remaining - $carried - $encashed;

                $entitlement = $employee->annual_leave_days === null
                    ? $default
                    : Value::int($employee->annual_leave_days);

                DB::table('leave_year_balances')->upsert(
                    [[
                        'tenant_id' => $tenantId,
                        'employee_id' => $employeeId,
                        'year' => $toYear,
                        'entitlement_days' => $entitlement,
                        'carried_over_days' => $carried,
                        'carryover_encashed_days' => $encashed,
                    ]],
                    ['tenant_id', 'employee_id', 'year'],
                    ['entitlement_days', 'carried_over_days', 'carryover_encashed_days'],
                );

                if ($encashed > 0) {
                    $this->recordEncashment($tenantId, $employeeId, $fromYear, $encashed, Value::float($employee->base_salary));
                }

                $totalCarried += $carried;
                $totalEncashed += $encashed;
                $totalDropped += max(0, $dropped);
                $processed++;
            }

            return [
                'from_year' => $fromYear,
                'to_year' => $toYear,
                'processed' => $processed,
                'total_carried' => $totalCarried,
                'total_encashed' => $totalEncashed,
                'total_dropped' => $totalDropped,
            ];
        });
    }

    /**
     * One encashment per employee per source year, and a payout that has
     * already been made is never rewritten — re-running the rollover must not
     * change money somebody has been paid.
     */
    private function recordEncashment(int $tenantId, int $employeeId, int $sourceYear, int $days, float $baseSalary): void
    {
        $dailyRate = round($baseSalary / 30, 2);

        DB::statement(
            'INSERT INTO leave_encashments'
            .' (tenant_id, employee_id, source_year, days, daily_rate, amount, status)'
            ." VALUES (?, ?, ?, ?, ?, ?, 'pending')"
            .' ON DUPLICATE KEY UPDATE'
            ."  days = IF(status = 'paid', days, VALUES(days)),"
            ."  daily_rate = IF(status = 'paid', daily_rate, VALUES(daily_rate)),"
            ."  amount = IF(status = 'paid', amount, VALUES(amount))",
            [$tenantId, $employeeId, $sourceYear, $days, $dailyRate, round($dailyRate * $days, 2)],
        );
    }
}
