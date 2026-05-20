<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$token = $_SERVER['HTTP_X_STATION_TOKEN'] ?? null;
if (!$token) Response::fail('Station token is required', 401);

$station = AttendanceStationModel::findByToken($token);
if (!$station) Response::fail('Invalid station token', 401);

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$gpsLat = isset($input['gps_lat']) ? (float) $input['gps_lat'] : null;
$gpsLng = isset($input['gps_lng']) ? (float) $input['gps_lng'] : null;

AttendanceStationModel::updateHeartbeat($station['id'], $gpsLat, $gpsLng);

if ($gpsLat !== null && $gpsLng !== null) {
    $branch = BranchModel::findById($station['branch_id'], $station['tenant_id']);
    if ($branch && $branch['latitude'] && $branch['longitude']) {
        $distance = GpsService::haversineMeters($gpsLat, $gpsLng, (float) $branch['latitude'], (float) $branch['longitude']);
        $radius = (int) ($branch['station_gps_radius_meters'] ?? 30);
        if ($distance > $radius * 3) {
            AttendanceStationModel::lockStation($station['id'], 'GPS out of range: ' . round($distance) . 'm');
            Response::success(['status' => 'locked', 'reason' => 'GPS out of range']);
        }
    }
}

if ($station['is_locked']) {
    Response::success(['status' => 'locked', 'reason' => $station['locked_reason']]);
}

Response::success(['status' => 'ok']);
