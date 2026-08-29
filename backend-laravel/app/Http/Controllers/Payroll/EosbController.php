<?php

declare(strict_types=1);

namespace App\Http\Controllers\Payroll;

use App\Domain\Time\TenantClock;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Support\Value;
use DateTimeImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/payroll/eosb_calculate.php.
 *
 * End-of-service benefit: years of service × the company's days-per-year × the
 * daily wage. Off unless the company has turned it on, because the entitlement
 * is jurisdiction-specific and inventing a number for a company that never
 * configured one would be worse than showing nothing.
 */
final class EosbController
{
    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = Value::int($request->query('employee_id'));

        if ($employeeId <= 0) {
            throw new ApiFailure('employee_id is required', 422, 'employee_id_required');
        }

        $employee = DB::table('employees')
            ->where('id', $employeeId)->where('tenant_id', $tenantId)
            ->first(['name', 'hire_date', 'base_salary']);

        if ($employee === null) {
            throw new ApiFailure('Employee not found', 404, 'not_found');
        }

        $settings = DB::table('payroll_statutory_settings')->where('tenant_id', $tenantId)->first();

        if ($settings === null || Value::int($settings->eosb_enabled) !== 1) {
            return ApiResponse::success([
                'employee_id' => $employeeId,
                'enabled' => false,
                'message' => 'EOSB is not enabled for this company',
            ]);
        }

        $daysPerYear = Value::float($settings->eosb_days_per_year);

        if ($daysPerYear <= 0) {
            throw new ApiFailure('Invalid eosb_days_per_year setting', 422, 'invalid_eosb_days_per_year');
        }

        $hireDate = Value::nullableString($employee->hire_date);

        if ($hireDate === null || $hireDate === '') {
            throw new ApiFailure('Employee has no hire_date', 422, 'employee_hire_date');
        }

        $service = self::yearsOfService($hireDate, TenantClock::date($tenantId));
        $dailyWage = Value::float($employee->base_salary) / 30;
        $amount = round($service * $daysPerYear * $dailyWage, 2);

        return ApiResponse::success([
            'employee_id' => $employeeId,
            'employee_name' => $employee->name,
            'enabled' => true,
            'hire_date' => $hireDate,
            'years_of_service' => round($service, 2),
            'eosb_days_per_year' => $daysPerYear,
            'daily_wage' => round($dailyWage, 2),
            'eosb_amount' => $amount,
            'breakdown' => [
                'years_of_service' => round($service, 2),
                'x_days_per_year' => $daysPerYear,
                'x_daily_wage' => round($dailyWage, 2),
                '= total' => $amount,
            ],
        ]);
    }

    /**
     * Whole years, plus the remaining months and days as fractions.
     *
     * Measured against the company's own date rather than the server's: an
     * entitlement that grows by a day depending on which side of midnight UTC
     * the request landed is not one anybody can check.
     */
    private static function yearsOfService(string $hireDate, string $asOf): float
    {
        $difference = (new DateTimeImmutable($asOf))->diff(new DateTimeImmutable($hireDate));

        return $difference->y + ($difference->m / 12) + ($difference->d / 365.25);
    }
}
