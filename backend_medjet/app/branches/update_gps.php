<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$branchId = (int) ($input['branch_id'] ?? 0);
$latitude = (float) ($input['latitude'] ?? 0);
$longitude = (float) ($input['longitude'] ?? 0);

Validator::required($branchId, 'branch_id');

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch) {
    Response::notFound('Branch');
}

BranchModel::update($branchId, $tenantId, [
    'latitude' => $latitude,
    'longitude' => $longitude,
]);

Response::success(['message' => 'GPS settings updated']);
