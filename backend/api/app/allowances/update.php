<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
$type = trim((string) ($input['type'] ?? ''));
$amount = (float) ($input['amount'] ?? 0);
$startMonth = (string) ($input['start_month'] ?? '');
$endMonth = isset($input['end_month']) && $input['end_month'] !== ''
    ? (string) $input['end_month'] : null;
$label = isset($input['label']) && trim((string) $input['label']) !== ''
    ? trim((string) $input['label']) : null;

Validator::required($id, 'id');
Validator::required($type, 'type');
Validator::required($startMonth, 'start_month');

if ($amount <= 0) {
    Response::fail('amount must be positive', 422, 'amount_positive');
}
if (!preg_match('/^\d{4}-\d{2}$/', $startMonth)) {
    Response::fail('start_month must be YYYY-MM', 422, 'start_month_yyyy_mm');
}
if ($endMonth !== null) {
    if (!preg_match('/^\d{4}-\d{2}$/', $endMonth)) {
        Response::fail('end_month must be YYYY-MM', 422, 'end_month_yyyy_mm');
    }
    if ($endMonth < $startMonth) {
        Response::fail('end_month cannot be before start_month', 422, 'end_month_cannot_before_start');
    }
}

$existing = AllowanceModel::findById($id, $tenantId);
if (!$existing) {
    Response::notFound('Allowance');
}

AllowanceModel::update($id, $tenantId, $type, $amount, $startMonth, $endMonth, $label);

AuditLogModel::log(
    $tenantId,
    $auth['admin_id'],
    'allowance.update',
    'employee',
    (int) $existing['employee_id'],
    ['id' => $id, 'amount' => $amount]
);

Response::success(['message' => 'Allowance updated']);
