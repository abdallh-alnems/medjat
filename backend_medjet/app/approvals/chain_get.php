<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_approvals');

$chainId = (int) ($_GET['chain_id'] ?? 0);
Validator::required($chainId, 'chain_id');

$chain = ApprovalChainModel::findById($chainId, $tenantId);
if (!$chain) {
    Response::notFound('Approval chain');
}

Response::success(['chain' => $chain]);
