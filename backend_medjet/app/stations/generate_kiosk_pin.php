<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$admin = AdminAuth::require('admin');
$tenantId = (int) $admin['tenant_id'];

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$stationId = (int) ($input['station_id'] ?? 0);
Validator::required($stationId, 'station_id');

$station = AttendanceStationModel::findById($stationId, $tenantId);
if (!$station) Response::fail('Station not found', 404);

KioskPinModel::cleanup();

$result = KioskPinModel::generate(
    $stationId,
    (int) $station['branch_id'],
    $tenantId,
    (int) $admin['admin_id']
);

AdminAuth::logAction('station.generate_pin', 'station', $stationId);

Response::success($result);
