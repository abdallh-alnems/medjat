<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$id = (int) ($input['id'] ?? $_GET['id'] ?? 0);
Validator::required($id, 'id');

$loan = LoanModel::findById($id, $tenantId);
if (!$loan) {
    Response::notFound('Loan');
}

$ok = LoanModel::cancel($id, $tenantId);
if (!$ok) {
    Response::fail('Loan cannot be cancelled in its current state', 409);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'loan.cancel', 'loan', $id);

Response::success(['message' => 'Loan cancelled']);
