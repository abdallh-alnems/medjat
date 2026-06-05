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

$chain = ApprovalChainModel::findById($chainId, $tenantId);
if (!$chain) {
    Response::notFound('Approval chain');
}

$minAmount = $input['min_amount'] ?? null;
$maxAmount = $input['max_amount'] ?? null;
if ($minAmount !== null && $maxAmount !== null && (float) $maxAmount < (float) $minAmount) {
    Response::fail('max_amount must be >= min_amount', 422);
}

$branchId = $input['branch_id'] ?? null;
if ($branchId !== null) {
    PermissionMiddleware::checkBranchAccess($auth, (int) $branchId);
}

// Only forward keys the client actually sent, so a partial update never
// overwrites untouched columns (e.g. nulling the NOT NULL `name`).
$data = [];
foreach (['name', 'name_ar', 'is_active', 'priority'] as $k) {
    if (array_key_exists($k, $input)) {
        $data[$k] = $input[$k];
    }
}
if (array_key_exists('min_amount', $input)) {
    $data['min_amount'] = $minAmount;
}
if (array_key_exists('max_amount', $input)) {
    $data['max_amount'] = $maxAmount;
}
if (array_key_exists('branch_id', $input)) {
    $data['branch_id'] = $branchId !== null ? (int) $branchId : null;
}

ApprovalChainModel::update($chainId, $tenantId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'approval_chain.update', 'approval_chain', $chainId);

Response::success(['message' => 'Approval chain updated']);
