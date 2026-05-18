<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$type = $input['type'] ?? 'verbal';
$reason = $input['reason'] ?? null;

Validator::required($employeeId, 'employee_id');
Validator::required($reason, 'reason');
Validator::enum($type, ['verbal', 'written', 'final'], 'type');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$id = WarningModel::add($employeeId, $tenantId, $type, $reason, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'warning.add', 'employee', $employeeId, ['type' => $type]);

Response::success(['id' => $id, 'message' => 'Warning issued']);
