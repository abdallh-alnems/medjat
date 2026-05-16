<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_leaves');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$date = $input['date'] ?? null;
$type = $input['type'] ?? 'annual';
$reason = $input['reason'] ?? null;

Validator::required($employeeId, 'employee_id');
Validator::required($date, 'date');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

LeaveModel::convertAbsenceToLeave($employeeId, $tenantId, $date, $type, $reason, $auth['user_id']);

AuditLogModel::log($tenantId, $auth['user_id'], 'leave.convert_absence', 'employee', $employeeId, ['date' => $date]);

Response::success(['message' => 'Absence converted to leave']);
