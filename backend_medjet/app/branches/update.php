<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$branchId = (int) ($input['branch_id'] ?? 0);
Validator::required($branchId, 'branch_id');

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch) {
    Response::notFound('Branch');
}

$updateData = [];
foreach (['name', 'address', 'latitude', 'longitude', 'gps_radius'] as $field) {
    if (isset($input[$field])) {
        $updateData[$field] = $input[$field];
    }
}

if (!empty($updateData)) {
    BranchModel::update($branchId, $tenantId, $updateData);
}

AuditLogModel::log($tenantId, $auth['user_id'], 'branch.update', 'branch', $branchId);

Response::success(['message' => 'Branch updated']);
