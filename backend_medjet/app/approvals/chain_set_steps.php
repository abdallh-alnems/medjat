<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_approvals');

$input = $auth['input'];
$chainId = (int) ($input['chain_id'] ?? 0);
$steps = $input['steps'] ?? [];

Validator::required($chainId, 'chain_id');

if (!is_array($steps) || empty($steps)) {
    Response::fail('steps must be a non-empty array', 422);
}

ApprovalChainModel::setSteps($tenantId, $chainId, $steps);

AuditLogModel::log($tenantId, $auth['admin_id'], 'approval_chain.set_steps', 'approval_chain', $chainId, ['step_count' => count($steps)]);

Response::success(['message' => 'Chain steps updated']);
