<?php
// Step a payroll slip one state back: paid → approved, or approved → draft.
// Used by the financial tab's "Revert" action when a slip needs corrections
// after approval/payment.
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$payrollId = (int) ($input['payroll_id'] ?? 0);
Validator::required($payrollId, 'payroll_id');

$prev = PayrollModel::revert($payrollId, $tenantId);
if ($prev === null) {
    Response::fail('Slip not found or already in draft', 422, 'slip_not_found_already_draft');
}

AuditLogModel::log(
    $tenantId,
    $auth['admin_id'],
    'payroll.revert',
    'payroll',
    $payrollId,
    ['from' => $prev]
);

PayrollCache::invalidate($tenantId);

Response::success([
    'message' => 'Payroll reverted',
    'from'    => $prev,
]);
