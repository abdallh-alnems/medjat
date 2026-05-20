<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'station_manage');

$input = $auth['input'];
$branchId = (int) ($input['branch_id'] ?? 0);
Validator::required($branchId, 'branch_id');
PermissionMiddleware::checkBranchAccess($auth, $branchId);

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch) Response::fail('Branch not found', 404);

$data = [];

if (isset($input['station_enabled'])) {
    $data['station_enabled'] = (int) $input['station_enabled'];
}
if (isset($input['station_methods'])) {
    Validator::enum($input['station_methods'], ['face_only', 'fingerprint_only', 'both_available'], 'station_methods');
    $data['station_methods'] = $input['station_methods'];
}
if (isset($input['station_gps_radius_meters'])) {
    $data['station_gps_radius_meters'] = (int) $input['station_gps_radius_meters'];
}
if (isset($input['station_confidence_threshold'])) {
    $data['station_confidence_threshold'] = (float) $input['station_confidence_threshold'];
}
if (isset($input['station_admin_pin'])) {
    $data['station_admin_pin_hash'] = password_hash($input['station_admin_pin'], PASSWORD_BCRYPT);
}
if (isset($input['station_anti_spoofing_enabled'])) {
    $data['station_anti_spoofing_enabled'] = (int) $input['station_anti_spoofing_enabled'];
}

if (empty($data)) {
    Response::fail('No fields to update', 400);
}

BranchModel::updateStationSettings($branchId, $tenantId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'branch.update_station_settings', 'branch', $branchId);

Response::success(['branch_id' => $branchId]);
