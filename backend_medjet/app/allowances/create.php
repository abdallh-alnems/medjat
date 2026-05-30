<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$type = trim((string) ($input['type'] ?? ''));
$amount = (float) ($input['amount'] ?? 0);
$startMonth = (string) ($input['start_month'] ?? '');
$endMonth = isset($input['end_month']) && $input['end_month'] !== ''
    ? (string) $input['end_month'] : null;
$label = isset($input['label']) && trim((string) $input['label']) !== ''
    ? trim((string) $input['label']) : null;

Validator::required($employeeId, 'employee_id');
Validator::required($type, 'type');
Validator::required($startMonth, 'start_month');

if ($amount <= 0) {
    Response::fail('amount must be positive', 422);
}
if (!preg_match('/^\d{4}-\d{2}$/', $startMonth)) {
    Response::fail('start_month must be YYYY-MM', 422);
}
if ($endMonth !== null) {
    if (!preg_match('/^\d{4}-\d{2}$/', $endMonth)) {
        Response::fail('end_month must be YYYY-MM', 422);
    }
    if ($endMonth < $startMonth) {
        Response::fail('end_month cannot be before start_month', 422);
    }
}

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$id = AllowanceModel::create(
    $tenantId,
    $employeeId,
    $type,
    $amount,
    $startMonth,
    $endMonth,
    $label,
    $auth['admin_id']
);

AuditLogModel::log(
    $tenantId,
    $auth['admin_id'],
    'allowance.create',
    'employee',
    $employeeId,
    ['id' => $id, 'type' => $type, 'amount' => $amount]
);

Response::success(['id' => $id, 'message' => 'Allowance added']);
