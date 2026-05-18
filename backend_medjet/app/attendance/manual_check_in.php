<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_attendance');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$branchId = (int) ($input['branch_id'] ?? 0);
$date = $input['date'] ?? date('Y-m-d');
$checkInTime = $input['check_in_time'] ?? '09:00:00';
$checkOutTime = $input['check_out_time'] ?? '17:00:00';

Validator::required($employeeId, 'employee_id');
Validator::required($branchId, 'branch_id');
Validator::date($date, 'date');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::fail('Employee not found', 404);
}

AttendanceModel::manualCheckIn($employeeId, $branchId, $tenantId, $date, $checkInTime, $checkOutTime, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'attendance.manual_check_in', 'employee', $employeeId);

Response::success(['message' => 'Manual attendance recorded']);
