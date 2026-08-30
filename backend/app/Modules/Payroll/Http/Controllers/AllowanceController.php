<?php

declare(strict_types=1);

namespace App\Modules\Payroll\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Payroll\Domain\PayrollCache;
use App\Modules\Payroll\Domain\PayrollCalculator;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/allowances/*.php.
 *
 * Standing monthly additions — housing, transport and the like — as opposed to
 * the one-off bonuses that sit beside them. An allowance has a window rather
 * than a date, which is what makes it recur.
 */
final class AllowanceController
{
    public const TYPES = ['housing', 'transport', 'food', 'communication', 'other'];

    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = Value::int($request->query('employee_id'));

        self::assertEmployeeExists($employeeId, $tenantId);

        $allowances = DB::table('employee_allowances')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)
            ->orderByDesc('start_month')->orderByDesc('id')
            ->get()
            ->map(static function (object $row): array {
                /** @var array<string, mixed> $columns */
                $columns = (array) $row;
                // The label the payslip will actually print, so the screen and
                // the payslip cannot disagree about what this is called.
                $columns['display_label'] = Value::string($columns['label'] ?? null)
                    ?: PayrollCalculator::allowanceLabel(Value::string($columns['type'] ?? null));

                return $columns;
            })->all();

        return ApiResponse::success([
            'allowances' => $allowances,
            'types' => self::TYPES,
        ]);
    }

    public function create(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $employeeId = Value::int($request->input('employee_id'));

        self::assertEmployeeExists($employeeId, $tenantId);

        $fields = $this->fields($request);

        $id = (int) DB::table('employee_allowances')->insertGetId($fields + [
            'tenant_id' => $tenantId,
            'employee_id' => $employeeId,
            'created_by' => $adminId,
        ]);

        AuditLog::record($tenantId, $adminId, 'allowance.create', 'employee', $employeeId, $fields);

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success(['id' => $id, 'message' => 'Allowance created']);
    }

    public function update(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        [$id, $existing] = $this->target($request, $tenantId);

        $fields = $this->fields($request);

        DB::table('employee_allowances')->where('id', $id)->where('tenant_id', $tenantId)->update($fields);

        AuditLog::record(
            $tenantId, $adminId, 'allowance.update', 'employee',
            Value::int($existing['employee_id'] ?? null), ['id' => $id] + $fields,
        );

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success(['message' => 'Allowance updated']);
    }

    public function delete(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        [$id, $existing] = $this->target($request, $tenantId);

        DB::table('employee_allowances')->where('id', $id)->where('tenant_id', $tenantId)->delete();

        AuditLog::record(
            $tenantId, $adminId, 'allowance.delete', 'employee',
            Value::int($existing['employee_id'] ?? null), ['id' => $id],
        );

        PayrollCache::invalidate($tenantId);

        return ApiResponse::success(['message' => 'Allowance deleted']);
    }

    /**
     * @return array<string, mixed>
     */
    private function fields(Request $request): array
    {
        $type = Value::string($request->input('type'));

        if (! in_array($type, self::TYPES, true)) {
            throw new ApiFailure('Invalid type', 422, 'invalid_type');
        }

        $amount = Value::float($request->input('amount'));

        if ($amount <= 0) {
            throw new ApiFailure('amount must be positive', 422, 'amount_positive');
        }

        $startMonth = Value::string($request->input('start_month'));

        if (preg_match('/^\d{4}-\d{2}$/', $startMonth) !== 1) {
            throw new ApiFailure('start_month must be YYYY-MM', 422, 'start_month_yyyy_mm');
        }

        // An open end is the common case: an allowance runs until somebody
        // stops it, not until a date chosen when it was created.
        $endMonth = Value::string($request->input('end_month')) ?: null;

        if ($endMonth !== null) {
            if (preg_match('/^\d{4}-\d{2}$/', $endMonth) !== 1) {
                throw new ApiFailure('end_month must be YYYY-MM', 422, 'end_month_yyyy_mm');
            }

            // Months in this form sort lexically, so the comparison is the
            // check.
            if ($endMonth < $startMonth) {
                throw new ApiFailure(
                    'end_month cannot be before start_month',
                    422,
                    'end_month_cannot_before_start',
                );
            }
        }

        return [
            'type' => $type,
            'label' => trim(Value::string($request->input('label'))) ?: null,
            'amount' => $amount,
            'start_month' => $startMonth,
            'end_month' => $endMonth,
        ];
    }

    /**
     * @return array{0: int, 1: array<string, mixed>}
     */
    private function target(Request $request, int $tenantId): array
    {
        $id = Value::int($request->input('id'));
        $row = $id > 0
            ? DB::table('employee_allowances')->where('id', $id)->where('tenant_id', $tenantId)->first()
            : null;

        if ($row === null) {
            throw new ApiFailure('Allowance not found', 404, 'not_found');
        }

        /** @var array<string, mixed> $existing */
        $existing = (array) $row;

        return [$id, $existing];
    }

    private static function assertEmployeeExists(int $employeeId, int $tenantId): void
    {
        $exists = $employeeId > 0
            && DB::table('employees')->where('id', $employeeId)->where('tenant_id', $tenantId)->exists();

        if (! $exists) {
            throw new ApiFailure('Employee not found', 404, 'not_found');
        }
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
