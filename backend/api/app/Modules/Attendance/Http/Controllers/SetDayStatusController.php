<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Models\Employee;
use App\Modules\Attendance\Services\SetDayStatusAction;
use App\Modules\Audit\Domain\AuditLog;
use App\Shared\Access\Permissions;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/attendance/set_day_status.php.
 */
final class SetDayStatusController
{
    public function __construct(private readonly SetDayStatusAction $setStatus) {}

    public function __invoke(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $employeeId = Value::int($request->input('employee_id'));
        $date = Value::string($request->input('date'));
        $status = Value::string($request->input('status'));

        if ($employeeId <= 0 || $date === '' || $status === '') {
            throw new ApiFailure('employee_id, date and status are required', 422, 'missing_fields');
        }

        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) !== 1) {
            throw new ApiFailure('Invalid date format. Use Y-m-d', 400, 'invalid_date');
        }

        if (! in_array($status, SetDayStatusAction::STATUSES, true)) {
            throw new ApiFailure('Invalid status', 422, 'invalid_status');
        }

        $employee = Employee::query()->forTenant($tenantId)->whereKey($employeeId)->first();
        if ($employee === null) {
            throw new ApiFailure('Employee not found', 404);
        }

        $currentStatus = Value::nullableString(DB::table('attendance')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)->where('date', $date)
            ->value('status'));

        // Moving a day into or out of leave changes somebody's balance, so it
        // needs the leave permission as well as the attendance one.
        if ($status === 'leave' || $currentStatus === 'leave') {
            $this->requireLeavePermission($admin);
        }

        [$checkIn, $checkOut] = $this->times($request, $status);
        [$mode, $value] = $this->deduction($request, $status);

        $result = $this->setStatus->execute(
            employee: $employee,
            tenantId: $tenantId,
            date: $date,
            status: $status,
            checkIn: $checkIn,
            checkOut: $checkOut,
            leaveType: $status === 'leave' ? $this->leaveType($request) : null,
            reason: $this->reason($request),
            recordedBy: $admin->id,
            deductionMode: $mode,
            deductionValue: $value,
        );

        AuditLog::record($tenantId, $admin->id, 'attendance.set_status', 'attendance', Value::int($result['record']['id'] ?? null), [
            'date' => $date,
            'from' => $result['previous_status'],
            'to' => $status,
        ]);

        return ApiResponse::success([
            'message' => 'Attendance day updated',
            'record' => $result['record'],
        ]);
    }

    /**
     * @return array{string|null, string|null}
     */
    private function times(Request $request, string $status): array
    {
        if ($status !== 'present') {
            // Times only mean anything on a day somebody was present.
            return [null, null];
        }

        $checkIn = $this->time($request, 'check_in_time');
        $checkOut = $this->time($request, 'check_out_time');

        if ($checkIn !== null && $checkOut !== null && strtotime($checkIn) >= strtotime($checkOut)) {
            throw new ApiFailure('Check-out time must be after check-in time', 422, 'check_out_time_after_check');
        }

        return [$checkIn, $checkOut];
    }

    private function time(Request $request, string $field): ?string
    {
        $value = Value::string($request->input($field));

        if ($value === '') {
            return null;
        }

        if (preg_match('/^\d{2}:\d{2}(:\d{2})?$/', $value) !== 1) {
            throw new ApiFailure(
                "Invalid time format for {$field} (expected HH:MM[:SS])",
                422,
                'invalid_time_format_expected_hh'
            );
        }

        return $value;
    }

    private function leaveType(Request $request): string
    {
        $type = Value::string($request->input('leave_type'), 'annual');
        $type = $type === '' ? 'annual' : $type;

        if (! in_array($type, SetDayStatusAction::LEAVE_TYPES, true)) {
            throw new ApiFailure('Invalid leave_type', 422, 'invalid_leave_type');
        }

        return $type;
    }

    /**
     * @return array{string, float|null}
     */
    private function deduction(Request $request, string $status): array
    {
        if ($status !== 'absent') {
            return ['auto', null];
        }

        $mode = Value::string($request->input('deduction_mode'), 'auto');
        $mode = $mode === '' ? 'auto' : $mode;

        if (! in_array($mode, SetDayStatusAction::DEDUCTION_MODES, true)) {
            throw new ApiFailure('Invalid deduction_mode', 422, 'invalid_deduction_mode');
        }

        if ($mode === 'auto') {
            return ['auto', null];
        }

        $raw = $request->input('deduction_value');
        if (! is_numeric($raw) || (float) $raw < 0) {
            throw new ApiFailure(
                'deduction_value must be a non-negative number',
                422,
                'deduction_value_non_negative_number'
            );
        }

        return [$mode, (float) $raw];
    }

    private function reason(Request $request): ?string
    {
        $reason = trim(Value::string($request->input('reason')));

        return $reason === '' ? null : $reason;
    }

    private function requireLeavePermission(Admin $admin): void
    {
        $held = Permissions::effectiveFor($admin->id, $admin->tenant_id ?? 0, $admin->role);

        if ($held === Permissions::ALL || in_array('manage_leaves', $held, true)) {
            return;
        }

        throw new ApiFailure('Missing permission: manage_leaves', 403, 'missing_permission');
    }
}
