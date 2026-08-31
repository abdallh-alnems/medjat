<?php

declare(strict_types=1);

namespace App\Modules\Categories\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Categories\Domain\EmployeeCategories;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/categories/*.php.
 *
 * Job categories — the grouping documents, payroll adjustments and reports all
 * scope themselves by.
 */
final class CategoryController
{
    public function index(Request $request): JsonResponse
    {
        return ApiResponse::success([
            'categories' => EmployeeCategories::forTenant(Value::int($request->attributes->get('tenant_id'))),
        ]);
    }

    public function create(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $name = trim(Value::string($request->input('name')));

        if ($name === '') {
            throw new ApiFailure('name is required', 422, 'name_required');
        }

        if (EmployeeCategories::nameTaken($name, $tenantId)) {
            throw new ApiFailure('category_name_exists', 409, 'category_name_exists');
        }

        $id = EmployeeCategories::create(
            $tenantId,
            $name,
            Value::nullableString($request->input('description')),
            Value::nullableString($request->input('color')),
        );

        AuditLog::record($tenantId, $adminId, 'employee_category.create', 'employee_category', $id);

        return ApiResponse::success(['category_id' => $id], 201);
    }

    public function update(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $id = self::existing($request, $tenantId);

        $fields = [];

        if ($request->has('name')) {
            $name = trim(Value::string($request->input('name')));

            if ($name === '') {
                throw new ApiFailure('name is required', 422, 'name_required');
            }

            if (EmployeeCategories::nameTaken($name, $tenantId, $id)) {
                throw new ApiFailure('category_name_exists', 409, 'category_name_exists');
            }

            $fields['name'] = $name;
        }

        foreach (['description', 'color'] as $field) {
            if ($request->has($field)) {
                $fields[$field] = Value::nullableString($request->input($field));
            }
        }

        if ($request->has('is_active')) {
            $fields['is_active'] = $request->boolean('is_active') ? 1 : 0;
        }

        EmployeeCategories::update($id, $tenantId, $fields);

        AuditLog::record($tenantId, $adminId, 'employee_category.update', 'employee_category', $id, $fields);

        return ApiResponse::success(['category_id' => $id]);
    }

    public function delete(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $id = self::existing($request, $tenantId);

        // Deleting it would drop the document requirement scoped to it, not
        // just the label.
        if (EmployeeCategories::usedByDocuments($id, $tenantId)) {
            throw new ApiFailure('category_in_use_cannot_delete', 409, 'category_cannot_delete');
        }

        EmployeeCategories::delete($id, $tenantId);

        AuditLog::record($tenantId, $adminId, 'employee_category.delete', 'employee_category', $id);

        return ApiResponse::success(['message' => 'Category deleted']);
    }

    /**
     * An employee's categories, replaced wholesale — the list is what they are
     * now, not a history of what has been added.
     */
    public function assign(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $employeeId = Value::int($request->input('employee_id'));

        $exists = DB::table('employees')->where('id', $employeeId)->where('tenant_id', $tenantId)->exists();

        if (! $exists) {
            throw new ApiFailure('Employee not found', 404, 'not_found');
        }

        $raw = $request->input('category_ids');
        $categoryIds = is_array($raw)
            ? array_values(array_map(static fn (mixed $id): int => Value::int($id), $raw))
            : [];

        EmployeeCategories::assignToEmployee($employeeId, $tenantId, $categoryIds);

        AuditLog::record($tenantId, $adminId, 'employee_category.assign', 'employee', $employeeId, [
            'category_ids' => $categoryIds,
        ]);

        return ApiResponse::success(['message' => 'Categories assigned']);
    }

    /**
     * A per-category exception to the company's browser-attendance switch.
     *
     * Behind company settings rather than employee management: this is the same
     * decision as the company switch at a finer grain, and somebody who may
     * rename a job category should not thereby be able to open the weakest
     * attendance channel for the people in it.
     */
    public function updateWebAccess(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;

        if (! $request->has('web_attendance_allowed')) {
            throw new ApiFailure(
                'web_attendance_allowed is required (true, false or null)',
                422,
                'web_attendance_allowed_required',
            );
        }

        $id = self::existing($request, $tenantId);
        $raw = $request->input('web_attendance_allowed');

        if ($raw === null || $raw === '') {
            $allowed = null;
        } else {
            $allowed = filter_var($raw, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);

            if ($allowed === null) {
                throw new ApiFailure(
                    'web_attendance_allowed must be true, false or null',
                    422,
                    'web_attendance_allowed_bool',
                );
            }
        }

        EmployeeCategories::setWebAccess($id, $tenantId, $allowed);

        AuditLog::record($tenantId, $adminId, 'employee_category.web_access', 'employee_category', $id, [
            'web_attendance_allowed' => $allowed,
        ]);

        return ApiResponse::success([
            'category_id' => $id,
            'web_attendance_allowed' => $allowed,
        ]);
    }

    private static function existing(Request $request, int $tenantId): int
    {
        $id = Value::int($request->input('id'));

        if ($id <= 0 || EmployeeCategories::find($id, $tenantId) === null) {
            throw new ApiFailure('Category not found', 404, 'not_found');
        }

        return $id;
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        return $admin;
    }
}
