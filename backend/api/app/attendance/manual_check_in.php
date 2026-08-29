<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_attendance');

$config = TenantModel::getAttendanceConfig($tenantId);
if (!in_array('manual', $config['methods'], true)) {
    Response::forbidden('Manual attendance is disabled for this company');
}

if ($config['admin_ids'] !== null) {
    if (!in_array((int) $auth['admin_id'], array_map('intval', $config['admin_ids']), true)) {
        Response::forbidden('You are not authorized to record manual attendance');
    }
}

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$branchId = (int) ($input['branch_id'] ?? 0);
$date = $input['date'] ?? date('Y-m-d');
$checkInTime = $input['check_in_time'] ?? null;
$checkOutTime = $input['check_out_time'] ?? null;
$notes = isset($input['notes']) ? trim((string) $input['notes']) : '';

Validator::required($employeeId, 'employee_id');
Validator::date($date, 'date');

if (!$checkInTime && !$checkOutTime) {
    Response::fail('Either check_in_time or check_out_time is required', 400, 'either_check_time_check_out');
}

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::fail('Employee not found', 404, 'employee_not_found');
}

if ($branchId > 0) {
    $branch = BranchModel::findById($branchId, $tenantId);
    if ($branch) {
        $branchMethods = $branch['attendance_methods'] !== null
            ? json_decode($branch['attendance_methods'], true)
            : null;
        if ($branchMethods !== null && !in_array('manual', $branchMethods, true)) {
            Response::forbidden('Manual attendance is disabled for this branch');
        }
    }
}

if ($checkInTime && $checkOutTime) {
    Validator::required($branchId, 'branch_id');
    AttendanceModel::manualCheckIn($employeeId, $branchId, $tenantId, $date, $checkInTime, $checkOutTime, $auth['admin_id']);
    if ($notes !== '') {
        AttendanceModel::updateNote($tenantId, $employeeId, $date, $notes);
    }
    AuditLogModel::log($tenantId, $auth['admin_id'], 'attendance.manual_check_in', 'employee', $employeeId);
    Response::success(['message' => 'Manual attendance recorded']);
}

if ($checkInTime) {
    Validator::required($branchId, 'branch_id');
    AttendanceModel::manualCheckInOnly($employeeId, $branchId, $tenantId, $date, $checkInTime, $auth['admin_id']);
    if ($notes !== '') {
        AttendanceModel::updateNote($tenantId, $employeeId, $date, $notes);
    }
    AuditLogModel::log($tenantId, $auth['admin_id'], 'attendance.manual_check_in', 'employee', $employeeId);
    Response::success(['message' => 'Manual check-in recorded']);
}

AttendanceModel::manualCheckOutOnly($employeeId, $tenantId, $date, $checkOutTime, $auth['admin_id']);
if ($notes !== '') {
    AttendanceModel::updateNote($tenantId, $employeeId, $date, $notes);
}
AuditLogModel::log($tenantId, $auth['admin_id'], 'attendance.manual_check_out', 'employee', $employeeId);
Response::success(['message' => 'Manual check-out recorded']);
