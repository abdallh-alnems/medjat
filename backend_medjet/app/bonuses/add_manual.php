<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$amount = (float) ($input['amount'] ?? 0);
$reason = $input['reason'] ?? null;

Validator::required($employeeId, 'employee_id');
Validator::required($amount, 'amount');
Validator::required($reason, 'reason');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$id = BonusRuleModel::addManualBonus($employeeId, $tenantId, $amount, $reason, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'bonus.manual', 'employee', $employeeId, ['amount' => $amount]);

Response::success(['id' => $id, 'message' => 'Manual bonus added']);
