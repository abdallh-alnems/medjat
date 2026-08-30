<?php

declare(strict_types=1);

namespace App\Modules\Settlements\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Models\Employee;
use App\Models\EmployeeAuthToken;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Settlements\Domain\Settlement;
use App\Modules\Settlements\Domain\SettlementCalculator;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/settlements/*.php.
 *
 * The final account between a company and somebody leaving it: what they are
 * owed, what they owe back, and the day the two stop accruing.
 */
final class SettlementController
{
    public function __construct(private readonly SettlementCalculator $calculator) {}

    /**
     * The saved settlement, if there is one, alongside a fresh computation the
     * page uses to prefill a new one.
     */
    public function show(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employee = $this->subject(Value::int($request->query('employee_id')), $tenantId);

        $settlement = Settlement::forEmployee($employee->id, $tenantId);

        // Computed as of the saved last working day when one exists, so the
        // suggestion sits beside the saved figures rather than drifting a day
        // further from them every time the page is opened.
        $asOf = Value::string($settlement['last_working_day'] ?? null)
            ?: TenantClock::date($tenantId);

        return ApiResponse::success([
            'employee' => [
                'id' => $employee->id,
                'name' => $employee->name,
                'status' => $employee->status,
                'base_salary' => Value::float($employee->getAttribute('base_salary')),
                'hire_date' => SettlementCalculator::hireDate($employee),
            ],
            'settlement' => $settlement,
            'suggested' => $this->calculator->compute($employee, $tenantId, substr($asOf, 0, 10)),
        ]);
    }

    /**
     * Recomputes for a different last working day without touching the draft.
     *
     * HR moves that date around while negotiating a leaving date, and each move
     * changes the gratuity, the leave encashment and the part-month salary.
     */
    public function preview(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employee = $this->subject(Value::int($request->query('employee_id')), $tenantId);

        $lastWorkingDay = Value::string($request->query('last_working_day'))
            ?: TenantClock::date($tenantId);

        self::assertDate($lastWorkingDay);

        return ApiResponse::success([
            'employee' => ['id' => $employee->id, 'name' => $employee->name],
            'last_working_day' => $lastWorkingDay,
            'suggested' => $this->calculator->compute($employee, $tenantId, $lastWorkingDay),
        ]);
    }

    public function save(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);
        $employee = $this->subject(Value::int($request->input('employee_id')), $tenantId);

        $lastWorkingDay = Value::string($request->input('last_working_day'));
        self::assertDate($lastWorkingDay);

        $reason = Value::string($request->input('reason'), 'resignation') ?: 'resignation';

        if (! in_array($reason, Settlement::REASONS, true)) {
            throw new ApiFailure('Invalid reason', 422, 'invalid_reason');
        }

        if ($employee->status === 'terminated') {
            throw new ApiFailure('الموظف منتهية خدمته بالفعل', 422, 'already_terminated');
        }

        $existing = Settlement::forEmployee($employee->id, $tenantId);

        if ($existing !== null && Value::string($existing['status'] ?? null) !== 'draft') {
            throw new ApiFailure('لا يمكن تعديل تسوية معتمدة', 409, 'settlement_locked');
        }

        $data = [
            'reason' => $reason,
            'notes' => $request->input('notes'),
            'last_working_day' => $lastWorkingDay,
            'hire_date' => $request->input('hire_date'),
            'line_items' => $request->input('line_items'),
        ];

        foreach (Settlement::FIGURES as $figure) {
            $data[$figure] = $request->input($figure);
        }

        $id = Settlement::save($tenantId, $employee->id, $data, $admin->id);

        AuditLog::record($tenantId, $admin->id, 'settlement.save', 'employee', $employee->id, [
            'settlement_id' => $id,
        ]);

        return ApiResponse::success([
            'settlement_id' => $id,
            'settlement' => Settlement::find($id, $tenantId),
            'message' => 'تم حفظ التسوية',
        ]);
    }

    /**
     * Approving is what ends the employment.
     *
     * The figures are frozen into the snapshot, the employee's service ends as
     * of the last working day, and their device token is revoked so the app
     * signs them out on its next request rather than continuing to show a
     * former employer's roster.
     */
    public function approve(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);
        $employee = $this->subject(Value::int($request->input('employee_id')), $tenantId);

        $settlement = $this->draft($employee->id, $tenantId);
        $id = Value::int($settlement['id'] ?? null);

        // The audit columns are joins, not settlement data; freezing them would
        // record an administrator's current name as part of the figures.
        $snapshot = $settlement;
        unset($snapshot['created_by_name'], $snapshot['approved_by_name']);

        if (! Settlement::approve($id, $tenantId, $admin->id, $snapshot)) {
            throw new ApiFailure('تعذر اعتماد التسوية', 409, 'approve_failed');
        }

        $lastWorkingDay = Value::string($settlement['last_working_day'] ?? null);

        DB::table('employees')->where('id', $employee->id)->where('tenant_id', $tenantId)->update([
            'status' => 'terminated',
            'terminated_at' => $lastWorkingDay,
            'updated_at' => DB::raw('NOW()'),
        ]);

        EmployeeAuthToken::revokeForEmployee($employee->id, 'service_terminated');

        AuditLog::record($tenantId, $admin->id, 'settlement.approve', 'employee', $employee->id, [
            'settlement_id' => $id,
            'net_amount' => Value::float($settlement['net_amount'] ?? null),
            'last_working_day' => $lastWorkingDay,
            'reason' => $settlement['reason'] ?? null,
        ]);

        return ApiResponse::success([
            'message' => 'تم اعتماد التسوية وإنهاء الخدمة',
            'settlement' => Settlement::find($id, $tenantId),
        ]);
    }

    public function markPaid(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);
        $employeeId = Value::int($request->input('employee_id'));

        $settlement = Settlement::forEmployee($employeeId, $tenantId);

        if ($settlement === null) {
            throw new ApiFailure('لا توجد تسوية محفوظة لهذا الموظف', 404, 'no_settlement');
        }

        $status = Value::string($settlement['status'] ?? null);

        if ($status === 'draft') {
            throw new ApiFailure('يجب اعتماد التسوية أولاً', 409, 'not_approved');
        }

        if ($status === 'paid') {
            throw new ApiFailure('التسوية مدفوعة بالفعل', 409, 'already_paid');
        }

        $id = Value::int($settlement['id'] ?? null);

        if (! Settlement::markPaid($id, $tenantId)) {
            throw new ApiFailure('تعذر تحديث التسوية', 409, 'mark_paid_failed');
        }

        AuditLog::record($tenantId, $admin->id, 'settlement.mark_paid', 'employee', $employeeId, [
            'settlement_id' => $id,
        ]);

        return ApiResponse::success([
            'message' => 'تم تسجيل صرف التسوية',
            'settlement' => Settlement::find($id, $tenantId),
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function draft(int $employeeId, int $tenantId): array
    {
        $settlement = Settlement::forEmployee($employeeId, $tenantId);

        if ($settlement === null) {
            throw new ApiFailure('لا توجد تسوية محفوظة لهذا الموظف', 404, 'no_settlement');
        }

        if (Value::string($settlement['status'] ?? null) !== 'draft') {
            throw new ApiFailure('التسوية معتمدة بالفعل', 409, 'already_approved');
        }

        return $settlement;
    }

    private function subject(int $employeeId, int $tenantId): Employee
    {
        if ($employeeId <= 0) {
            throw new ApiFailure('Employee ID required', 422, 'employee_id_required');
        }

        $employee = Employee::query()->where('id', $employeeId)->where('tenant_id', $tenantId)->first();

        if ($employee === null) {
            throw new ApiFailure('Employee not found', 404, 'not_found');
        }

        return $employee;
    }

    private static function assertDate(string $date): void
    {
        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) !== 1 || strtotime($date) === false) {
            throw new ApiFailure('last_working_day must be a valid date', 422, 'invalid_last_working_day');
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
