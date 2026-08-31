<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Modules\Payroll\Domain\PayrollCalculator;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/payroll/calculate.php.
 *
 * One employee's figures for a month, computed fresh and written nowhere. The
 * full-cycle view, with no as-of clamp — this is the "what would this month
 * cost" question, not "what has been earned so far".
 */
final class CalculateController
{
    public function __construct(private readonly PayrollCalculator $calculator) {}

    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = Value::int($request->query('employee_id'));

        if ($employeeId <= 0) {
            throw new ApiFailure('employee_id is required', 422, 'employee_id_required');
        }

        $month = Value::string($request->query('month'), '') ?: substr(TenantClock::date($tenantId), 0, 7);

        return ApiResponse::success(
            $this->calculator->calculate($employeeId, $month, $tenantId)
        );
    }
}
