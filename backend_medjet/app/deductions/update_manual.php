<?php
// Edit an existing manual deduction line. Manual entries only (statutory
// items, late/absence and loan deductions are derived from rules/attendance
// and cannot be edited here).
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
$amount = isset($input['amount']) ? (float) $input['amount'] : null;
$reason = trim((string) ($input['reason'] ?? ''));

Validator::required($id, 'id');
Validator::required($amount, 'amount');

if ($amount <= 0) {
    Response::fail('amount must be positive', 422, 'amount_positive');
}

$existing = DeductionRuleModel::findManualById($id, $tenantId);
if (!$existing) {
    Response::notFound('Deduction');
}

DeductionRuleModel::updateManualDeduction($id, $tenantId, $amount, $reason);

AuditLogModel::log(
    $tenantId,
    $auth['admin_id'],
    'deduction.manual_update',
    'employee',
    (int) $existing['employee_id'],
    ['id' => $id, 'amount' => $amount]
);

Response::success(['message' => 'Manual deduction updated']);
