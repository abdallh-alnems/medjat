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

$allowedMethods = AttendanceMethodResolver::ALLOWED;
$attendanceMethods = $input['attendance_methods'] ?? null;

if ($attendanceMethods !== null) {
    if (!is_array($attendanceMethods)) {
        Response::fail('attendance_methods must be an array or null', 422, 'attendance_methods_array_null');
    }
    if (empty($attendanceMethods)) {
        Response::fail('attendance_methods cannot be empty. Use null to inherit company settings.', 400, 'attendance_methods_cannot_empty_null');
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
    Response::fail('gps_radius_meters must be between 10 and 5000', 422, 'gps_radius_meters_between_10');
}

$allowOffline = null;
if (array_key_exists('allow_offline_attendance', $input)) {
    $val = $input['allow_offline_attendance'];
    if ($val === null) {
        $allowOffline = null;
    } else {
        $allowOffline = filter_var($val, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($allowOffline === null) {
            Response::fail('allow_offline_attendance must be true, false, or null', 422, 'allow_offline_attendance_true_false');
        }
    }
}

BranchModel::updateAttendanceMethods($branchId, $tenantId, $attendanceMethods, $gpsRadiusMeters, $allowOffline);

// Per-branch face overrides. Omit the keys to leave them untouched; send null
// to go back to inheriting the company settings.
if (array_key_exists('face_match_threshold', $input)
    || array_key_exists('face_liveness_required', $input)) {
    $faceThreshold = $input['face_match_threshold'] ?? null;
    if ($faceThreshold !== null) {
        $faceThreshold = (float) $faceThreshold;
        if ($faceThreshold < 0.3 || $faceThreshold > 0.95) {
            Response::fail('face_match_threshold must be between 0.3 and 0.95', 422, 'face_match_threshold_range');
        }
    }

    $faceLiveness = null;
    if (($input['face_liveness_required'] ?? null) !== null) {
        $faceLiveness = filter_var($input['face_liveness_required'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($faceLiveness === null) {
            Response::fail('face_liveness_required must be true, false, or null', 422, 'face_liveness_required_bool');
        }
    }

    BranchModel::updateFaceSettings($branchId, $tenantId, $faceThreshold, $faceLiveness);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'branch.update_attendance_method', 'branch', $branchId);

Response::success(['message' => 'Branch attendance methods updated']);
