<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_approvals');

$input = $auth['input'];
$name = $input['name'] ?? null;
$requestType = $input['request_type'] ?? null;

Validator::required($name, 'name');
Validator::required($requestType, 'request_type');
Validator::enum($requestType, ApprovalChainModel::REQUEST_TYPES, 'request_type');

$minAmount = $input['min_amount'] ?? null;
$maxAmount = $input['max_amount'] ?? null;
if ($minAmount !== null && $maxAmount !== null && (float) $maxAmount < (float) $minAmount) {
    Response::fail('max_amount must be >= min_amount', 422);
}

$branchId = $input['branch_id'] ?? null;
if ($branchId !== null) {
    PermissionMiddleware::checkBranchAccess($auth, (int) $branchId);
}

$chainId = ApprovalChainModel::create($tenantId, [
    'name' => $name,
    'name_ar' => $input['name_ar'] ?? null,
    'request_type' => $requestType,
    'is_active' => $input['is_active'] ?? 1,
    'min_amount' => $minAmount,
    'max_amount' => $maxAmount,
    'branch_id' => $branchId !== null ? (int) $branchId : null,
    'priority' => $input['priority'] ?? 0,
], $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'approval_chain.create', 'approval_chain', $chainId);

Response::success(['chain_id' => $chainId, 'message' => 'Approval chain created']);
