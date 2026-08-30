<?php

declare(strict_types=1);

namespace App\Modules\Employees\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use App\Modules\Audit\Domain\AuditLog;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/employees/delete.php.
 *
 * Deactivation rather than deletion: the attendance, payroll and document
 * history stays, because a company that let somebody go still has to be able to
 * answer questions about the years they worked.
 */
final class DeleteEmployeeController
{
    public function __invoke(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = Value::int($request->input('employee_id'));

        if ($employeeId <= 0) {
            throw new ApiFailure('employee_id is required', 422, 'missing_fields');
        }

        $employee = Employee::query()->forTenant($tenantId)->whereKey($employeeId)->first();
        if ($employee === null) {
            throw new ApiFailure('Employee not found', 404);
        }

        DB::table('employees')->where('id', $employeeId)->where('tenant_id', $tenantId)
            ->update(['status' => 'terminated']);

        // Sign them out of the app: an ended service should not leave a live
        // token on a handset the company no longer controls.
        EmployeeAuthToken::revokeForEmployee($employeeId, 'service_terminated');

        AuditLog::record($tenantId, $admin->id, 'employee.delete', 'employee', $employeeId);

        return ApiResponse::success(['message' => 'Employee deactivated']);
    }
}
