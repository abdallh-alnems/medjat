<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$input = $auth['input'];
$branchId = (int) ($input['branch_id'] ?? 0);
$latitude = (float) ($input['latitude'] ?? 0);
$longitude = (float) ($input['longitude'] ?? 0);
$qrCode = $input['qr_code'] ?? null;

Validator::required($branchId, 'branch_id');

$employee = EmployeeModel::findByAdminId($auth['admin_id'], $tenantId);
if (!$employee) {
    Response::fail('Employee profile not found', 404);
}

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch) {
    Response::fail('Branch not found', 404);
}

if ($qrCode && $branch['qr_code'] !== $qrCode) {
    Response::fail('Invalid QR code for this branch', 400);
}

$gpsResult = GpsService::validateCheckIn($latitude, $longitude, $branchId, $tenantId);
if (!$gpsResult['valid']) {
    Response::fail($gpsResult['message'], 400, 'GPS_OUT_OF_RANGE');
}

AttendanceModel::checkIn($employee['id'], $branchId, $tenantId, 'qr_gps');

Response::success([
    'message' => 'Check-in successful',
    'time' => date('H:i:s'),
    'branch' => $branch['name'],
]);
