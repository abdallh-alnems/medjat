<?php

declare(strict_types=1);

namespace App\Modules\Employees\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Employees\Services\EmployeeQuery;
use App\Shared\Http\ApiResponse;
use App\Shared\Http\Middleware\RequireBranchAccess;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/employees/list.php.
 */
final class ListEmployeesController
{
    public function __construct(private readonly EmployeeQuery $employees) {}

    public function __invoke(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $branchId = Value::int($request->query('branch_id'));
        $branchId = $branchId > 0 ? $branchId : null;

        if ($branchId !== null) {
            RequireBranchAccess::assert($admin, $branchId);
        }

        $result = $this->employees->paginate($tenantId, $request->query());
        $result['stats'] = $this->employees->statusCounts($tenantId, $branchId);

        return ApiResponse::success($result);
    }
}
