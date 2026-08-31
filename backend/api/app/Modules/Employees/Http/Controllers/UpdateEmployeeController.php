<?php

declare(strict_types=1);

namespace App\Modules\Employees\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Models\Employee;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Employees\Services\CreateEmployeeAction;
use App\Shared\Contact\PhoneValidator;
use App\Shared\Http\ApiResponse;
use App\Shared\Http\Middleware\RequireBranchAccess;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/employees/update.php.
 *
 * A partial update: only the keys actually sent are touched, so a screen that
 * edits three fields cannot blank the twenty it never showed.
 */
final class UpdateEmployeeController
{
    /** @var list<string> */
    private const EDITABLE = [
        'name', 'phone', 'email', 'job_title', 'base_salary', 'branch_id', 'hire_date',
        'national_id', 'work_start_time', 'work_end_time', 'shift_id',
        'bank_name', 'bank_account_number', 'bank_iban', 'bank_swift',
        'auto_terminate_at',
    ];

    /** Fields where an empty string means "clear it", not "set it to empty". */
    private const DATE_FIELDS = [
        'hire_date', 'iqama_expiry', 'passport_expiry', 'work_permit_expiry',
        'contract_start', 'contract_end', 'health_insurance_expiry', 'auto_terminate_at',
    ];

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

        if ($request->has('branch_id')) {
            RequireBranchAccess::assert($admin, Value::nullableInt($request->input('branch_id')));
        }

        $changes = $this->changes($request);

        if ($changes !== []) {
            DB::table('employees')->where('id', $employeeId)->where('tenant_id', $tenantId)->update($changes);
        }

        // Sent at all, even as an empty list, means "these are now their
        // categories" — which is how somebody is removed from one.
        if ($request->has('category_ids')) {
            $this->syncCategories($request, $employeeId, $tenantId);
        }

        AuditLog::record($tenantId, $admin->id, 'employee.update', 'employee', $employeeId, $changes);

        return ApiResponse::success(['message' => 'Employee updated']);
    }

    /**
     * @return array<string, mixed>
     */
    private function changes(Request $request): array
    {
        $changes = [];
        $fields = array_merge(self::EDITABLE, CreateEmployeeAction::COMPLIANCE_FIELDS);

        foreach ($fields as $field) {
            if (! $request->has($field)) {
                continue;
            }

            $value = $request->input($field);
            $changes[$field] = $value === '' && in_array($field, self::DATE_FIELDS, true) ? null : $value;
        }

        if (isset($changes['phone']) && $changes['phone'] !== '') {
            $normalised = PhoneValidator::normalize(Value::string($changes['phone']));
            if ($normalised === null) {
                throw new ApiFailure('Invalid phone number', 422, 'invalid_phone_number');
            }
            $changes['phone'] = $normalised;
        }

        if ($request->has('annual_leave_days')) {
            $changes['annual_leave_days'] = $this->annualLeaveDays($request->input('annual_leave_days'));
        }

        if ($request->has('weekly_off_days')) {
            $changes['weekly_off_days'] = $this->weeklyOffDays($request->input('weekly_off_days'));
        }

        return $changes;
    }

    /**
     * Empty means "inherit the company default", which is different from zero —
     * zero is a deliberate "no annual leave".
     */
    private function annualLeaveDays(mixed $value): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }

        $days = Value::int($value, -1);

        if ($days < 0 || $days > 366) {
            throw new ApiFailure(
                'annual_leave_days must be between 0 and 366, or empty to inherit',
                422,
                'annual_leave_days_between_0'
            );
        }

        return $days;
    }

    private function weeklyOffDays(mixed $value): ?string
    {
        $valid = ['saturday', 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday'];

        if (is_string($value)) {
            $value = $value === '' ? [] : explode(',', $value);
        }

        if (! is_array($value)) {
            return null;
        }

        $days = array_values(array_unique(array_intersect(
            $valid,
            array_map(static fn (mixed $day): string => is_string($day) ? trim($day) : '', $value),
        )));

        return $days === [] ? null : implode(',', $days);
    }

    private function syncCategories(Request $request, int $employeeId, int $tenantId): void
    {
        $submitted = $request->input('category_ids');
        $ids = is_array($submitted)
            ? array_values(array_filter(
                array_map(static fn (mixed $id): int => Value::int($id), $submitted),
                static fn (int $id): bool => $id > 0,
            ))
            : [];

        DB::table('employee_category_assignments')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)->delete();

        foreach ($ids as $categoryId) {
            DB::table('employee_category_assignments')->insertOrIgnore([
                'tenant_id' => $tenantId,
                'employee_id' => $employeeId,
                'category_id' => $categoryId,
            ]);
        }
    }
}
