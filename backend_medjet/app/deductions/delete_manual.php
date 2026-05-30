<?php
// Delete a manual deduction line.
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
Validator::required($id, 'id');

$existing = DeductionRuleModel::findManualById($id, $tenantId);
if (!$existing) {
    Response::notFound('Deduction');
}

DeductionRuleModel::deleteManualDeduction($id, $tenantId);

AuditLogModel::log(
    $tenantId,
    $auth['admin_id'],
    'deduction.manual_delete',
    'employee',
    (int) $existing['employee_id'],
    ['id' => $id, 'amount' => (float) $existing['amount']]
);

Response::success(['message' => 'Manual deduction deleted']);
