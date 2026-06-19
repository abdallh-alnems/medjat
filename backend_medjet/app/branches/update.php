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
foreach (['name', 'address', 'latitude', 'longitude'] as $field) {
    if (isset($input[$field])) {
        $updateData[$field] = $input[$field];
    }
}

// GPS geofence radius (meters) for QR+GPS / GPS-only attendance.
if (array_key_exists('gps_radius_meters', $input)) {
    $radius = (int) $input['gps_radius_meters'];
    if ($radius < 5 || $radius > 5000) {
        Response::fail('gps_radius_meters must be between 5 and 5000', 422, 'gps_radius_meters_between_5');
    }
    $updateData['gps_radius_meters'] = $radius;
}

// Per-branch attendance cycle override: 1-28, or null to inherit company default.
if (array_key_exists('cycle_start_day', $input)) {
    $val = $input['cycle_start_day'];
    if ($val === null || $val === '') {
        $updateData['cycle_start_day'] = null;
    } else {
        $day = (int) $val;
        if ($day < 1 || $day > 28) {
            Response::fail('cycle_start_day must be between 1 and 28, or null', 422, 'cycle_start_day_between_1');
        }
        $updateData['cycle_start_day'] = $day;
    }
}

if (!empty($updateData)) {
    BranchModel::update($branchId, $tenantId, $updateData);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'branch.update', 'branch', $branchId);

Response::success(['message' => 'Branch updated']);
