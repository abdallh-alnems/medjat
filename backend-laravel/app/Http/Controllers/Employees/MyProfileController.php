<?php

declare(strict_types=1);

namespace App\Http\Controllers\Employees;

use App\Domain\Documents\DocumentChecklist;
use App\Domain\Leave\LeaveBalance;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Employee;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/employees/my_profile.php.
 */
final class MyProfileController
{
    public function __invoke(Request $request): JsonResponse
    {
        $employee = $request->attributes->get('employee');
        if (! $employee instanceof Employee) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));

        return ApiResponse::success([
            'employee' => $employee->toArray(),
            'documents' => DocumentChecklist::forEmployee($employee->id, $tenantId),
            'leave_balance' => LeaveBalance::forEmployee($employee->id, $tenantId, (int) date('Y')),
        ]);
    }
}
