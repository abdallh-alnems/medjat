<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$id = (int) ($_GET['id'] ?? 0);
Validator::required($id, 'id');

$loan = LoanModel::findById($id, $tenantId);
if (!$loan) {
    Response::notFound('Loan');
}

$loan['installments'] = LoanModel::getInstallments($id, $tenantId);

Response::success(['loan' => $loan]);
