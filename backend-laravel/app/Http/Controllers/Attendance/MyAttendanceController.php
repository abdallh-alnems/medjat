<?php

declare(strict_types=1);

namespace App\Http\Controllers\Attendance;

use App\Domain\Attendance\AttendanceMethod;
use App\Domain\Time\TenantClock;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Branch;
use App\Models\Employee;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/attendance/get_my_attendance.php.
 *
 * The employee's month, plus everything the home screen needs to decide what to
 * offer — carried on this one call rather than spread over three, because the
 * app makes it on launch and most of the answers are "no".
 */
final class MyAttendanceController
{
    public function __invoke(Request $request): JsonResponse
    {
        $employee = $request->attributes->get('employee');
        if (! $employee instanceof Employee) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $month = Value::string($request->query('month'), TenantClock::now($tenantId)->format('Y-m'));

        $records = DB::table('attendance')
            ->where('employee_id', $employee->id)
            ->where('tenant_id', $tenantId)
            ->whereRaw("DATE_FORMAT(date, '%Y-%m') = ?", [$month])
            ->orderBy('date')
            ->get();

        return ApiResponse::success([
            'records' => $records,
            'month' => $month,
            'employee_id' => $employee->id,
            'attendance_config' => $this->config($employee, $tenantId),
            'today_shift' => $this->todayShift($employee, $tenantId),
        ]);
    }

    /**
     * Null for an employee with no branch, rather than a half-populated object.
     * That matches what crew check-in does: no branch means no geofence to
     * verify against, so it refuses anyway and offering the button would be a
     * dead end.
     *
     * @return array<string, mixed>|null
     */
    private function config(Employee $employee, int $tenantId): ?array
    {
        if ($employee->branch_id === null) {
            return null;
        }

        $branch = Branch::query()->forTenant($tenantId)->whereKey($employee->branch_id)->first();
        if ($branch === null) {
            return null;
        }

        $geofence = $branch->effectiveGeofence();

        return [
            'branch_id' => $branch->id,
            'branch_name' => $branch->name,
            'methods' => AttendanceMethod::resolveFor($employee, $tenantId),
            'gps_radius_meters' => $geofence['radius'],
            'allow_offline' => $branch->allowsOffline(),
            // The app raises the device-biometric prompt before submitting when
            // this is set. The server enforces it regardless; this only stops
            // the employee being rejected after doing the work.
            'require_local_biometric' => Value::int(
                DB::table('tenants')->where('id', $tenantId)->value('require_local_biometric')
            ) === 1,
            'branch_lat' => $geofence['lat'],
            'branch_lng' => $geofence['lng'],
            // Whether to offer the crew screen at all. Answered on a call the
            // home screen already makes, rather than by every employee hitting
            // the crew endpoint on launch to be told they supervise nobody —
            // which is true of almost all of them. Derived the same way, so the
            // two cannot disagree.
            'is_crew_supervisor' => Employee::query()
                ->where('crew_supervisor_id', $employee->id)
                ->where('tenant_id', $tenantId)
                ->exists(),
        ];
    }

    /**
     * Today's expected hours. A published rotation cell overrides the standing
     * shift; a cell naming no shift is an explicit rest day, which is different
     * from having no cell at all.
     *
     * @return array<string, mixed>
     */
    private function todayShift(Employee $employee, int $tenantId): array
    {
        $today = TenantClock::date($tenantId);

        $cell = DB::table('employee_shift_schedule as ess')
            ->leftJoin('shifts as s', 's.id', '=', 'ess.shift_id')
            ->where('ess.employee_id', $employee->id)
            ->where('ess.tenant_id', $tenantId)
            ->where('ess.work_date', $today)
            ->where('ess.status', 'published')
            ->first(['ess.shift_id', 's.start_time', 's.end_time']);

        if ($cell !== null) {
            $isRestDay = $cell->shift_id === null;

            return [
                'start_time' => $isRestDay ? null : $cell->start_time,
                'end_time' => $isRestDay ? null : $cell->end_time,
                'shift_name' => null,
                'is_rest_day' => $isRestDay,
            ];
        }

        return [
            'start_time' => $employee->getAttribute('work_start_time'),
            'end_time' => $employee->getAttribute('work_end_time'),
            'shift_name' => null,
            'is_rest_day' => false,
        ];
    }
}
