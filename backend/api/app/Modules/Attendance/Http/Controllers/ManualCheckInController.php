<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Models\Employee;
use App\Modules\Attendance\Domain\AttendanceMethod;
use App\Modules\Attendance\Services\ManualAttendanceAction;
use App\Modules\Audit\Domain\AuditLog;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/attendance/manual_check_in.php.
 *
 * Attendance recorded for an employee by an administrator. Gated twice: the
 * company has to permit manual attendance at all, and — when it names them — the
 * caller has to be on the list of administrators allowed to record it. Recording
 * someone else's hours is the one action here with no evidence behind it, so who
 * may do it is worth narrowing.
 */
final class ManualCheckInController
{
    public function __construct(private readonly ManualAttendanceAction $manual) {}

    public function __invoke(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $this->assertCompanyAllowsIt($admin, $tenantId);

        $employeeId = Value::int($request->input('employee_id'));
        $branchId = Value::int($request->input('branch_id'));
        $date = Value::string($request->input('date'), date('Y-m-d'));
        $checkIn = $this->time($request, 'check_in_time');
        $checkOut = $this->time($request, 'check_out_time');
        $note = trim(Value::string($request->input('notes')));

        if ($employeeId <= 0) {
            throw new ApiFailure('employee_id is required', 422, 'missing_fields');
        }

        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) !== 1) {
            throw new ApiFailure('Invalid date format. Use Y-m-d', 400, 'invalid_date');
        }

        if ($checkIn === null && $checkOut === null) {
            throw new ApiFailure(
                'Either check_in_time or check_out_time is required',
                400,
                'either_check_time_check_out'
            );
        }

        $employee = Employee::query()->forTenant($tenantId)->whereKey($employeeId)->first();
        if ($employee === null) {
            throw new ApiFailure('Employee not found', 404, 'employee_not_found');
        }

        if ($branchId > 0) {
            $this->assertBranchAllowsIt($branchId, $tenantId);
        }

        $action = 'attendance.manual_check_in';

        if ($checkIn !== null && $checkOut !== null) {
            $this->requireBranch($branchId);
            $this->manual->wholeDay($employee, $branchId, $tenantId, $date, $checkIn, $checkOut, $admin->id);
            $message = 'Manual attendance recorded';
        } elseif ($checkIn !== null) {
            $this->requireBranch($branchId);
            $this->manual->checkInOnly($employee, $branchId, $tenantId, $date, $checkIn, $admin->id);
            $message = 'Manual check-in recorded';
        } else {
            $this->manual->checkOutOnly($employee, $tenantId, $date, (string) $checkOut, $admin->id);
            $message = 'Manual check-out recorded';
            $action = 'attendance.manual_check_out';
        }

        if ($note !== '') {
            $this->manual->setNoteForDay($tenantId, $employeeId, $date, $note);
        }

        AuditLog::record($tenantId, $admin->id, $action, 'employee', $employeeId);

        return ApiResponse::success(['message' => $message]);
    }

    private function requireBranch(int $branchId): void
    {
        if ($branchId <= 0) {
            throw new ApiFailure('branch_id is required', 422, 'missing_fields');
        }
    }

    private function time(Request $request, string $field): ?string
    {
        $value = Value::string($request->input($field));

        return $value === '' ? null : $value;
    }

    /**
     * The company has to permit manual attendance, and when it names the
     * administrators allowed to record it, the caller has to be one of them.
     */
    private function assertCompanyAllowsIt(Admin $admin, int $tenantId): void
    {
        $tenant = DB::table('tenants')->where('id', $tenantId)
            ->first(['attendance_methods', 'manual_attendance_admin_ids']);

        $methods = AttendanceMethod::decode($tenant?->attendance_methods);

        if (! in_array('manual', $methods, true)) {
            throw new ApiFailure('Manual attendance is disabled for this company', 403, 'manual_disabled');
        }

        $allowed = $tenant?->manual_attendance_admin_ids;
        if ($allowed === null) {
            return;
        }

        $ids = json_decode(Value::string($allowed), true);
        if (! is_array($ids)) {
            return;
        }

        if (! in_array($admin->id, array_map(static fn (mixed $id): int => Value::int($id), $ids), true)) {
            throw new ApiFailure('You are not authorized to record manual attendance', 403, 'manual_not_authorized');
        }
    }

    /** A branch may opt out even when the company allows it. */
    private function assertBranchAllowsIt(int $branchId, int $tenantId): void
    {
        $stored = DB::table('branches')->where('id', $branchId)->where('tenant_id', $tenantId)
            ->value('attendance_methods');

        if ($stored === null) {
            return;
        }

        if (! in_array('manual', AttendanceMethod::decode($stored), true)) {
            throw new ApiFailure('Manual attendance is disabled for this branch', 403, 'manual_disabled_branch');
        }
    }
}
