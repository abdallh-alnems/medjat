<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$endNote = isset($input['end_note']) && $input['end_note'] !== '' ? trim((string) $input['end_note']) : null;

Validator::required($employeeId, 'employee_id');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$active = EmployeeSuspensionModel::getActiveForEmployee($employeeId, $tenantId);
if (!$active) {
    Response::fail('Employee has no active suspension', 422);
}

EmployeeSuspensionModel::end((int) $active['id'], $tenantId, $auth['admin_id'], $endNote);

// Restore the status the employee held before the suspension (default active).
$restore = $active['previous_status'] ?: 'active';
EmployeeModel::update($employeeId, $tenantId, ['status' => $restore]);

AuditLogModel::log($tenantId, $auth['admin_id'], 'employee.end_suspension', 'employee', $employeeId, [
    'suspension_id' => (int) $active['id'],
    'restored_status' => $restore,
]);

Response::success(['message' => 'Suspension ended', 'restored_status' => $restore]);
