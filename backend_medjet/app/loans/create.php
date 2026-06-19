<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$type = $input['type'] ?? 'loan';
$totalAmount = (float) ($input['total_amount'] ?? 0);
$installmentsCount = (int) ($input['installments_count'] ?? 0);
$startMonth = $input['start_month'] ?? date('Y-m');
$reason = $input['reason'] ?? null;

Validator::required($employeeId, 'employee_id');
Validator::required($totalAmount, 'total_amount');
Validator::numeric($totalAmount, 'total_amount', 0.01);
Validator::required($installmentsCount, 'installments_count');
$type = Validator::enum($type, LoanModel::TYPES, 'type');

if ($installmentsCount < 1) {
    Response::fail('installments_count must be at least 1', 422, 'installments_count_at_least_1');
}
if (!preg_match('/^\d{4}-\d{2}$/', $startMonth)) {
    Response::fail('start_month must be in YYYY-MM format', 422, 'start_month_yyyy_mm_format');
}

$installmentAmount = round($totalAmount / $installmentsCount, 2);

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$id = LoanModel::create(
    $tenantId, $employeeId, $type, $totalAmount,
    $installmentAmount, $installmentsCount, $startMonth, $reason, $auth['admin_id']
);

AuditLogModel::log($tenantId, $auth['admin_id'], 'loan.create', 'loan', $id, [
    'type' => $type,
    'total_amount' => $totalAmount,
    'installments' => $installmentsCount,
]);

Response::success([
    'id' => $id,
    'installment_amount' => $installmentAmount,
    'message' => 'Loan created',
]);
