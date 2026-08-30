<?php

declare(strict_types=1);

namespace App\Modules\Dashboard\Http\Controllers;

use App\Modules\Dashboard\Domain\LiveBoard;
use App\Modules\Leave\Domain\LeaveRequests;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/dashboard/live_attendance.php.
 *
 * Who is in, who is out, who has not come — right now.
 */
final class LiveAttendanceController
{
    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        // The tenant's clock, not the server's: "today" in Cairo is not
        // "today" in UTC for six hours of every day, and this screen is read
        // during exactly those hours.
        $now = TenantClock::now($tenantId);
        $today = $now->format('Y-m-d');
        $nowTime = $now->format('H:i:s');

        $rows = LiveBoard::rows(
            $tenantId,
            $today,
            self::filter($request->query('branch_id')),
            self::filter($request->query('shift_id')),
            self::filter($request->query('category_id')),
        );

        $onLeave = LeaveRequests::employeesOnLeave($tenantId, $today);

        $summary = [
            'total' => 0, 'in' => 0, 'out' => 0, 'not_in' => 0,
            'pre_shift' => 0, 'absent' => 0, 'leave' => 0, 'late' => 0,
        ];

        $employees = [];

        foreach ($rows as $row) {
            $employeeId = Value::int($row['employee_id'] ?? null);
            $checkIn = Value::nullableString($row['check_in_time'] ?? null);
            $checkOut = Value::nullableString($row['check_out_time'] ?? null);
            $status = Value::nullableString($row['attendance_status'] ?? null);
            $lateMinutes = Value::int($row['late_minutes'] ?? null);
            $isLate = $lateMinutes > 0;

            $reason = null;

            if ($checkIn !== null && $checkOut !== null) {
                $derived = 'out';
            } elseif ($checkIn !== null) {
                $derived = 'in';
            } elseif ($status === 'absent') {
                $derived = 'absent';
            } elseif (in_array($status, LiveBoard::OFF_STATUSES, true)) {
                $derived = 'leave';
                $notes = trim(Value::string($row['attendance_notes'] ?? null));
                $reason = $notes !== '' ? $notes : ($status === 'leave' ? null : $status);
            } elseif (isset($onLeave[$employeeId])) {
                $derived = 'leave';
                $reason = LeaveRequests::reasonOn($employeeId, $tenantId, $today);
            } else {
                // Nothing recorded either way. Split "the shift has not started"
                // from "in-shift no-show" so a night worker is not flagged as
                // missing all morning.
                $derived = LiveBoard::isPreShift(
                    Value::nullableString($row['shift_start'] ?? null),
                    Value::nullableString($row['shift_end'] ?? null),
                    $nowTime,
                ) ? 'pre_shift' : 'not_in';
            }

            $summary['total']++;
            $summary[$derived]++;

            if ($isLate && ($derived === 'in' || $derived === 'out')) {
                $summary['late']++;
            }

            $employees[] = [
                'employee_id' => $employeeId,
                'name' => $row['name'] ?? null,
                'job_title' => $row['job_title'] ?? null,
                'branch_id' => Value::nullableInt($row['branch_id'] ?? null),
                'branch_name' => $row['branch_name'] ?? null,
                'derived_status' => $derived,
                'leave_reason' => $reason,
                'attendance_status' => $status,
                'check_in_time' => $checkIn,
                'check_out_time' => $checkOut,
                'late_minutes' => $lateMinutes,
                'is_late' => $isLate,
                'check_in_method' => $row['check_in_method'] ?? null,
                'is_offline' => Value::int($row['is_offline'] ?? null) === 1,
            ];
        }

        return ApiResponse::success([
            'employees' => $employees,
            'summary' => $summary,
            'server_time' => $now->format('c'),
            'date' => $today,
        ]);
    }

    private static function filter(mixed $raw): ?int
    {
        $id = Value::int($raw);

        return $id > 0 ? $id : null;
    }
}
