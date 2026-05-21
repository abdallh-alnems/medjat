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

$allowedMethods = ['qr_gps', 'gps_only', 'manual', 'station'];
$attendanceMethods = $input['attendance_methods'] ?? null;

if ($attendanceMethods !== null) {
    if (!is_array($attendanceMethods)) {
        Response::fail('attendance_methods must be an array or null', 422);
    }
    if (empty($attendanceMethods)) {
        Response::fail('attendance_methods cannot be empty. Use null to inherit company settings.', 400);
    }
    foreach ($attendanceMethods as $m) {
        if (!in_array($m, $allowedMethods, true)) {
            Response::fail('Invalid attendance method: ' . $m . '. Allowed: ' . implode(', ', $allowedMethods), 422);
        }
    }
    $attendanceMethods = array_values(array_unique($attendanceMethods));
}

$gpsRadiusMeters = (int) ($input['gps_radius_meters'] ?? ($branch['gps_radius_meters'] ?? 100));
if ($gpsRadiusMeters < 10 || $gpsRadiusMeters > 5000) {
    Response::fail('gps_radius_meters must be between 10 and 5000', 422);
}

$allowOffline = null;
if (array_key_exists('allow_offline_attendance', $input)) {
    $val = $input['allow_offline_attendance'];
    if ($val === null) {
        $allowOffline = null;
    } else {
        $allowOffline = filter_var($val, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($allowOffline === null) {
            Response::fail('allow_offline_attendance must be true, false, or null', 422);
        }
    }
}

BranchModel::updateAttendanceMethods($branchId, $tenantId, $attendanceMethods, $gpsRadiusMeters, $allowOffline);

AuditLogModel::log($tenantId, $auth['admin_id'], 'branch.update_attendance_method', 'branch', $branchId);

Response::success(['message' => 'Branch attendance methods updated']);
