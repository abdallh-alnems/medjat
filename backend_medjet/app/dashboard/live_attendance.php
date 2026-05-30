<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'view_reports');

$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;
$shiftId = ($_GET['shift_id'] ?? null) ? (int) $_GET['shift_id'] : null;
$categoryId = ($_GET['category_id'] ?? null) ? (int) $_GET['category_id'] : null;

// "Today" resolved in the tenant timezone (fallback to server time).
$tenant = TenantModel::findById($tenantId);
$tz = $tenant['timezone'] ?? null;
try {
    $now = new DateTime('now', $tz ? new DateTimeZone($tz) : null);
} catch (Exception $e) {
    $now = new DateTime('now');
}
$today = $now->format('Y-m-d');

$rows = AttendanceModel::getLiveBoard($tenantId, $today, $branchId, $shiftId, $categoryId);

$summary = [
    'total' => 0,
    'in' => 0,
    'out' => 0,
    'not_in' => 0,
    'pre_shift' => 0,
    'absent' => 0,
    'leave' => 0,
    'late' => 0,
];
$employees = [];

$nowTime = $now->format('H:i:s');

foreach ($rows as $row) {
    $checkIn = $row['check_in_time'] ?? null;
    $checkOut = $row['check_out_time'] ?? null;
    $attStatus = $row['attendance_status'] ?? null;
    $lateMinutes = (int) ($row['late_minutes'] ?? 0);
    $isLate = $lateMinutes > 0;

    $leaveReason = null;
    if ($checkIn && $checkOut) {
        $derived = 'out';                                    // checked in and out
    } elseif ($checkIn) {
        $derived = 'in';                                     // currently inside
    } elseif ($attStatus === 'absent') {
        $derived = 'absent';
    } elseif (in_array($attStatus, ['leave', 'holiday', 'weekly_off'], true)) {
        $derived = 'leave';
        $notes = trim((string) ($row['attendance_notes'] ?? ''));
        if ($attStatus === 'holiday') {
            $leaveReason = $notes !== '' ? $notes : 'holiday';
        } elseif ($attStatus === 'weekly_off') {
            $leaveReason = $notes !== '' ? $notes : 'weekly_off';
        } else {
            $leaveReason = $notes !== '' ? $notes : null;
        }
    } elseif (LeaveModel::isEmployeeOnLeave((int) $row['employee_id'], $today, $tenantId)) {
        $derived = 'leave';                                  // approved leave today
        $leaveReason = LeaveModel::getActiveLeaveTypeForEmployee(
            (int) $row['employee_id'],
            $today,
            $tenantId
        );
    } else {
        // No check-in and no recorded status: split into "shift hasn't started
        // yet" vs "in-shift no-show" so a night-shift worker isn't flagged as
        // not-arrived during the morning. Normal shift (end > start): pre-shift
        // when now < start. Overnight shift (end <= start, crosses midnight):
        // pre-shift only in the gap (now > end AND now < start).
        $shiftStart = $row['shift_start'] ?? null;
        $shiftEnd = $row['shift_end'] ?? null;
        $isPreShift = false;
        if ($shiftStart !== null) {
            if ($shiftEnd === null || $shiftEnd > $shiftStart) {
                $isPreShift = $nowTime < $shiftStart;
            } else {
                $isPreShift = $nowTime > $shiftEnd && $nowTime < $shiftStart;
            }
        }
        $derived = $isPreShift ? 'pre_shift' : 'not_in';
    }

    $summary['total']++;
    $summary[$derived]++;
    if ($isLate && ($derived === 'in' || $derived === 'out')) {
        $summary['late']++;
    }

    $employees[] = [
        'employee_id' => (int) $row['employee_id'],
        'name' => $row['name'],
        'job_title' => $row['job_title'],
        'branch_id' => $row['branch_id'] !== null ? (int) $row['branch_id'] : null,
        'branch_name' => $row['branch_name'],
        'derived_status' => $derived,
        'leave_reason' => $leaveReason,
        'attendance_status' => $attStatus,
        'check_in_time' => $checkIn,
        'check_out_time' => $checkOut,
        'late_minutes' => $lateMinutes,
        'is_late' => $isLate,
        'check_in_method' => $row['check_in_method'],
        'is_offline' => (bool) ($row['is_offline'] ?? false),
    ];
}

Response::success([
    'employees' => $employees,
    'summary' => $summary,
    'server_time' => $now->format('c'),
    'date' => $today,
]);
