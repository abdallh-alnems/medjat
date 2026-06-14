<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];

$input = $auth['input'];
$branchId = (int) ($input['branch_id'] ?? 0);
$latitude = (float) ($input['latitude'] ?? 0);
$longitude = (float) ($input['longitude'] ?? 0);
$qrCode = $input['qr_code'] ?? null;
$isVpn = isset($input['is_vpn']) && (int) $input['is_vpn'] === 1;

Validator::required($branchId, 'branch_id');

$employee = $auth['employee'];

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch) {
    Response::fail('Branch not found', 404);
}

// Enforce the attendance method configured for this branch. Self check-in
// from the employee app is only valid for qr_gps / gps_only; manual is
// handled elsewhere (admin records it).
$methods = AttendanceMethodResolver::resolveForEmployee($employee, $tenantId);
$requestedMethod = $qrCode ? 'qr_gps' : 'gps_only';

if (!in_array($requestedMethod, $methods, true)) {
    if ($requestedMethod === 'qr_gps' && in_array('gps_only', $methods, true)) {
        Response::fail('QR check-in is not enabled for this branch', 403, 'METHOD_NOT_ALLOWED');
    }
    if ($requestedMethod === 'gps_only' && in_array('qr_gps', $methods, true)) {
        Response::fail('QR code is required for this branch', 400, 'QR_REQUIRED');
    }
    Response::fail('Self check-in is disabled for this branch', 403, 'METHOD_NOT_ALLOWED');
}

if ($qrCode && $branch['qr_code'] !== $qrCode) {
    Response::fail('Invalid QR code for this branch', 400);
}

// Both qr_gps and gps_only require GPS, so the employee must send a real
// location. Missing/denied location reads as 0,0 — reject it instead of
// letting a QR code pass without any GPS verification.
if ($latitude == 0.0 && $longitude == 0.0) {
    Response::fail('Location is required for check-in', 400, 'LOCATION_REQUIRED');
}

$gpsResult = GpsService::validateCheckIn($latitude, $longitude, $branchId, $tenantId);
if (!$gpsResult['valid']) {
    Response::fail($gpsResult['message'], 400, $gpsResult['reason'] ?? 'GPS_OUT_OF_RANGE');
}

AttendanceModel::checkIn($employee['id'], $branchId, $tenantId, $requestedMethod, null, $latitude ?: null, $longitude ?: null, $isVpn);

if ($isVpn) {
    try {
        AttendanceSecurityModel::log($tenantId, (int) $employee['id'], $branchId, 'vpn', 'flagged', $latitude ?: null, $longitude ?: null);
    } catch (Exception $e) {
        error_log('VPN security log failed: ' . $e->getMessage());
    }
}

Response::success([
    'message' => 'Check-in successful',
    'time' => date('H:i:s'),
    'branch' => $branch['name'],
]);
