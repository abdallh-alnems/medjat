<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$name = $input['name'] ?? null;
$address = $input['address'] ?? null;
$latitude = (float) ($input['latitude'] ?? 0);
$longitude = (float) ($input['longitude'] ?? 0);

Validator::required($name, 'name');

$branchId = BranchModel::create($tenantId, [
    'name' => $name,
    'address' => $address,
    'latitude' => $latitude,
    'longitude' => $longitude,
]);

AuditLogModel::log($tenantId, $auth['admin_id'], 'branch.create', 'branch', $branchId);

Response::success(['branch_id' => $branchId], 201);
