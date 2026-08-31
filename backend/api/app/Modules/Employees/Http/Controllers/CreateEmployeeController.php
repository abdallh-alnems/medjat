<?php

declare(strict_types=1);

namespace App\Modules\Employees\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Employees\Services\CreateEmployeeAction;
use App\Shared\Http\ApiResponse;
use App\Shared\Http\Middleware\RequireBranchAccess;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/employees/create.php.
 */
final class CreateEmployeeController
{
    public function __construct(private readonly CreateEmployeeAction $create) {}

    public function __invoke(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        RequireBranchAccess::assert($admin, Value::nullableInt($request->input('branch_id')));

        $result = $this->create->execute($request->all(), $tenantId, $admin->id);

        return ApiResponse::success([
            'employee_id' => $result['employee_id'],
            'activation_code' => $result['activation_code'],
            'activation_token' => $result['activation_token'],
            'join_link' => $result['join_link'],
            'phone' => $result['phone'],
            'activation_expires_in_hours' => \App\Models\ActivationCode::VALIDITY_HOURS,
        ], 201);
    }
}
