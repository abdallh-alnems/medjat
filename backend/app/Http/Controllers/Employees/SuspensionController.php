<?php

declare(strict_types=1);

namespace App\Http\Controllers\Employees;

use App\Domain\Audit\AuditLog;
use App\Domain\Employees\Suspension;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Models\Employee;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports suspend.php, end_suspension.php and get_suspensions.php.
 */
final class SuspensionController
{
    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employee = $this->employee($request, $tenantId, Value::int($request->query('employee_id')));

        // Reconciled on the way in: a suspension that quietly outlives its own
        // end date is somebody unable to work for a reason nobody remembers.
        Suspension::reconcileExpired($tenantId, date('Y-m-d'));

        $history = DB::table('employee_suspensions as s')
            ->leftJoin('admins as c', 'c.id', '=', 's.created_by')
            ->leftJoin('admins as e', 'e.id', '=', 's.ended_by')
            ->where('s.employee_id', $employee->id)
            ->where('s.tenant_id', $tenantId)
            ->orderByDesc('s.start_date')
            ->orderByDesc('s.id')
            ->get(['s.*', 'c.name as created_by_name', 'e.name as ended_by_name']);

        return ApiResponse::success([
            'suspensions' => array_values(array_map(static fn (object $r): array => (array) $r, $history->all())),
            'active' => Suspension::activeFor($employee->id, $tenantId),
        ]);
    }

    public function open(Request $request): JsonResponse
    {
        [$admin, $tenantId] = $this->context($request);
        $employee = $this->employee($request, $tenantId, Value::int($request->input('employee_id')));

        $reason = trim(Value::string($request->input('reason')));
        if ($reason === '') {
            throw new ApiFailure('reason is required', 422, 'missing_fields');
        }

        if ($employee->status === 'terminated') {
            throw new ApiFailure('Cannot suspend a terminated employee', 422, 'cannot_suspend_terminated_employee');
        }

        $payMode = Value::string($request->input('pay_mode'), 'unpaid');
        if (! in_array($payMode, Suspension::PAY_MODES, true)) {
            throw new ApiFailure('Invalid pay_mode', 422, 'invalid_pay_mode');
        }

        $payPercentage = null;
        if ($payMode === 'partial') {
            $payPercentage = Value::float($request->input('pay_percentage'), -1);
            // Exclusive at both ends: 0 is 'unpaid' and 100 is 'full', and
            // storing either here would be the same thing said two ways.
            if ($payPercentage <= 0 || $payPercentage >= 100) {
                throw new ApiFailure(
                    'pay_percentage must be between 0 and 100 for partial pay',
                    422,
                    'pay_percentage_between_0_100'
                );
            }
        }

        $startDate = $this->date($request, 'start_date', date('Y-m-d'));
        $endDate = $this->date($request, 'end_date', null);

        if ($endDate !== null && $endDate < $startDate) {
            throw new ApiFailure('end_date must be on or after start_date', 422, 'end_date_after_start_date');
        }

        if (Suspension::activeFor($employee->id, $tenantId) !== null) {
            throw new ApiFailure('Employee already has an active suspension', 409, 'employee_already_active_suspension');
        }

        $id = Suspension::open($tenantId, $employee->id, [
            'reason' => $reason,
            'pay_mode' => $payMode,
            'pay_percentage' => $payPercentage,
            'start_date' => $startDate,
            'end_date' => $endDate,
            // Recorded, not assumed: somebody suspended while on leave goes
            // back to being on leave, and that cannot be reconstructed later.
            'previous_status' => $employee->status,
        ], $admin->id);

        DB::table('employees')->where('id', $employee->id)->update(['status' => 'suspended']);

        AuditLog::record($tenantId, $admin->id, 'employee.suspend', 'employee', $employee->id, [
            'suspension_id' => $id,
            'pay_mode' => $payMode,
            'pay_percentage' => $payPercentage,
            'start_date' => $startDate,
            'end_date' => $endDate,
        ]);

        return ApiResponse::success(['id' => $id, 'message' => 'Employee suspended']);
    }

    public function close(Request $request): JsonResponse
    {
        [$admin, $tenantId] = $this->context($request);
        $employee = $this->employee($request, $tenantId, Value::int($request->input('employee_id')));

        $active = Suspension::activeFor($employee->id, $tenantId);
        if ($active === null) {
            throw new ApiFailure('Employee has no active suspension', 422, 'employee_active_suspension');
        }

        $note = trim(Value::string($request->input('end_note')));
        Suspension::close(Value::int($active->id), $tenantId, $admin->id, $note === '' ? null : $note);

        $restored = Value::string($active->previous_status, 'active') ?: 'active';
        DB::table('employees')->where('id', $employee->id)->update(['status' => $restored]);

        AuditLog::record($tenantId, $admin->id, 'employee.end_suspension', 'employee', $employee->id, [
            'suspension_id' => Value::int($active->id),
            'restored_status' => $restored,
        ]);

        return ApiResponse::success(['message' => 'Suspension ended', 'restored_status' => $restored]);
    }

    /**
     * @return array{Admin, int}
     */
    private function context(Request $request): array
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        return [$admin, Value::int($request->attributes->get('tenant_id'))];
    }

    private function employee(Request $request, int $tenantId, int $employeeId): Employee
    {
        if ($employeeId <= 0) {
            throw new ApiFailure('employee_id is required', 422, 'missing_fields');
        }

        $employee = Employee::query()->forTenant($tenantId)->whereKey($employeeId)->first();
        if ($employee === null) {
            throw new ApiFailure('Employee not found', 404);
        }

        return $employee;
    }

    private function date(Request $request, string $field, ?string $default): ?string
    {
        $value = Value::string($request->input($field));

        if ($value === '') {
            return $default;
        }

        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $value) !== 1) {
            throw new ApiFailure("Invalid {$field} date. Use Y-m-d", 400, 'invalid_date');
        }

        return $value;
    }
}
