<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_attendance');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$date       = $input['date'] ?? null;
$status     = $input['status'] ?? null;
$checkIn    = isset($input['check_in_time'])  && $input['check_in_time']  !== '' ? (string) $input['check_in_time']  : null;
$checkOut   = isset($input['check_out_time']) && $input['check_out_time'] !== '' ? (string) $input['check_out_time'] : null;
$leaveType  = isset($input['leave_type']) && $input['leave_type'] !== '' ? (string) $input['leave_type'] : null;
$reason     = isset($input['reason']) && trim((string) $input['reason']) !== '' ? trim((string) $input['reason']) : null;
$deductionMode  = isset($input['deduction_mode']) && $input['deduction_mode'] !== '' ? (string) $input['deduction_mode'] : 'auto';
$deductionValue = isset($input['deduction_value']) && $input['deduction_value'] !== '' ? (float) $input['deduction_value'] : null;

Validator::required($employeeId, 'employee_id');
Validator::required($date, 'date');
Validator::date($date, 'date');
Validator::required($status, 'status');

$allowedStatuses = ['present', 'absent', 'leave', 'holiday', 'weekly_off'];
if (!in_array($status, $allowedStatuses, true)) {
    Response::fail('Invalid status', 422);
}

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

// Find the day's current status so we know if a leave permission is also needed.
$existing = Database::fetchOne(
    "SELECT status FROM attendance WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
    [$employeeId, $date, $tenantId]
);
$involvesLeave = $status === 'leave' || ($existing && $existing['status'] === 'leave');
if ($involvesLeave) {
    PermissionMiddleware::check($auth, 'manage_leaves');
}

// Per-status validation.
if ($status === 'present') {
    foreach (['check_in_time' => $checkIn, 'check_out_time' => $checkOut] as $field => $val) {
        if ($val !== null && !preg_match('/^\d{2}:\d{2}(:\d{2})?$/', $val)) {
            Response::fail("Invalid time format for {$field} (expected HH:MM[:SS])", 422);
        }
    }
    if ($checkIn !== null && $checkOut !== null && strtotime($checkIn) >= strtotime($checkOut)) {
        Response::fail('Check-out time must be after check-in time', 422);
    }
} else {
    // Times only make sense for a present day.
    $checkIn = null;
    $checkOut = null;
}

if ($status === 'leave') {
    $leaveType = $leaveType ?? 'annual';
    $allowedTypes = ['annual', 'sick', 'personal', 'unpaid'];
    if (!in_array($leaveType, $allowedTypes, true)) {
        Response::fail('Invalid leave_type', 422);
    }
} else {
    $leaveType = null;
}

// Deduction override is meaningful only for absent days.
if ($status === 'absent') {
    if (!in_array($deductionMode, ['auto', 'days', 'amount'], true)) {
        Response::fail('Invalid deduction_mode', 422);
    }
    if ($deductionMode !== 'auto') {
        if ($deductionValue === null || $deductionValue < 0) {
            Response::fail('deduction_value must be a non-negative number', 422);
        }
    } else {
        $deductionValue = null;
    }
} else {
    $deductionMode = 'auto';
    $deductionValue = null;
}

$record = AttendanceModel::setDayStatus(
    $employee,
    $tenantId,
    $date,
    $status,
    $checkIn,
    $checkOut,
    $leaveType,
    $reason,
    $auth['admin_id'],
    $deductionMode,
    $deductionValue
);

AuditLogModel::log(
    $tenantId,
    $auth['admin_id'],
    'attendance.set_status',
    'attendance',
    (int) ($record['id'] ?? 0),
    [
        'date' => $date,
        'from' => $existing['status'] ?? null,
        'to' => $status,
        'leave_type' => $leaveType,
    ]
);

Response::success([
    'message' => 'Attendance day updated',
    'record' => $record,
]);
