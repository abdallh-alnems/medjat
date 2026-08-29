<?php

declare(strict_types=1);

namespace App\Http\Controllers\Attendance;

use App\Domain\Attendance\AttendanceMethod;
use App\Domain\Audit\AuditLog;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Models\Employee;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/attendance/set_method_override.php.
 *
 * Sets or clears the attendance-method override for a category or one employee.
 * Branch overrides keep their own endpoint because they also carry the geofence
 * radius and the offline flag.
 */
final class SetMethodOverrideController
{
    public function __invoke(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $scopeType = Value::string($request->input('scope_type'));
        $scopeId = Value::int($request->input('scope_id'));

        if (! in_array($scopeType, ['category', 'employee'], true)) {
            throw new ApiFailure('scope_type must be category or employee', 422, 'scope_type_category_employee');
        }

        if ($scopeId <= 0) {
            throw new ApiFailure('scope_id is required', 422, 'missing_fields');
        }

        $methods = $this->methods($request);

        // A scope that does not exist is a 404 rather than a silent no-op: the
        // caller believes they configured something.
        $table = $scopeType === 'category' ? 'employee_categories' : 'employees';
        $exists = DB::table($table)->where('id', $scopeId)->where('tenant_id', $tenantId)->exists();

        if (! $exists) {
            throw new ApiFailure($scopeType === 'category' ? 'Category not found' : 'Employee not found', 404);
        }

        DB::table($table)->where('id', $scopeId)->where('tenant_id', $tenantId)->update([
            'attendance_methods' => $methods === null ? null : json_encode($methods),
        ]);

        AuditLog::record($tenantId, $admin->id, 'attendance.set_method_override', $scopeType, $scopeId, [
            'attendance_methods' => $methods,
        ]);

        return ApiResponse::success(['message' => 'Attendance method override updated']);
    }

    /**
     * null means "inherit", which is different from an empty list — an empty
     * list would be a scope that permits nothing at all, and nobody sets that
     * on purpose.
     *
     * @return list<string>|null
     */
    private function methods(Request $request): ?array
    {
        $submitted = $request->input('attendance_methods');

        if ($submitted === null) {
            return null;
        }

        if (! is_array($submitted) || $submitted === []) {
            throw new ApiFailure(
                'attendance_methods must be a non-empty array, or null to inherit',
                422,
                'attendance_methods_non_empty_array'
            );
        }

        foreach ($submitted as $method) {
            if (! is_string($method) || ! in_array($method, AttendanceMethod::ALLOWED, true)) {
                throw new ApiFailure(
                    'Invalid attendance method: '.Value::string($method),
                    422,
                    'invalid_attendance_method'
                );
            }
        }

        /** @var list<string> */
        return array_values(array_unique($submitted));
    }
}
