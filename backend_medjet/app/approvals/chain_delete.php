<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_approvals');

$input = $auth['input'];
$chainId = (int) ($input['chain_id'] ?? 0);
Validator::required($chainId, 'chain_id');

$deleted = ApprovalChainModel::delete($chainId, $tenantId);
if (!$deleted) {
    Response::notFound('Approval chain');
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'approval_chain.delete', 'approval_chain', $chainId);

Response::success(['message' => 'Approval chain deleted']);
