<?php
// Edit an existing manual bonus line.
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
$amount = isset($input['amount']) ? (float) $input['amount'] : null;
$reason = $input['reason'] ?? null;

Validator::required($id, 'id');
Validator::required($amount, 'amount');
Validator::required($reason, 'reason');

if ($amount <= 0) {
    Response::fail('amount must be positive', 422);
}

$existing = BonusRuleModel::findManualById($id, $tenantId);
if (!$existing) {
    Response::notFound('Bonus');
}

BonusRuleModel::updateManualBonus($id, $tenantId, $amount, $reason);

AuditLogModel::log(
    $tenantId,
    $auth['admin_id'],
    'bonus.manual_update',
    'employee',
    (int) $existing['employee_id'],
    ['id' => $id, 'amount' => $amount]
);

Response::success(['message' => 'Manual bonus updated']);
