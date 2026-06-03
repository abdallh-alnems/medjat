<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$token = $_SERVER['HTTP_X_STATION_TOKEN'] ?? null;
if (!$token) Response::fail('Station token is required', 401);

$station = AttendanceStationModel::findByToken($token);
if (!$station) Response::fail('Invalid station token', 401);
if ($station['is_locked']) Response::fail('Station is locked', 403);

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$method = $input['method'] ?? null;
$confidence = isset($input['confidence']) ? (float) $input['confidence'] : null;
$gpsLat = isset($input['gps_lat']) ? (float) $input['gps_lat'] : null;
$gpsLng = isset($input['gps_lng']) ? (float) $input['gps_lng'] : null;
$capturedImage = $input['captured_image_base64'] ?? null;

Validator::required($method, 'method');
Validator::enum($method, ['face', 'fingerprint', 'both', 'qr'], 'method');

$stationMethods = $station['station_methods'] ?? 'face_only';
if ($method === 'face' && !in_array($stationMethods, ['face_only', 'both'], true)) {
    Response::fail('Face method is not enabled for this station', 403);
}

$branchLat = (float) $station['branch_lat'] ?? 0;
$branchLng = (float) $station['branch_lng'] ?? 0;
$gpsRadius = (int) $station['station_gps_radius_meters'] ?? 30;

if ($method === 'qr') {
    $qrToken = $input['qr_token'] ?? null;
    Validator::required($qrToken, 'qr_token');

    $payload = StationQrTokenService::verify($qrToken);
    if (!$payload) {
        Response::fail('Invalid or expired QR token', 400);
    }

    $employeeId = (int) $payload['employee_id'];
    $employeeTenant = (int) $payload['tenant_id'];

    if ($employeeTenant != $station['tenant_id']) {
        Response::fail('Employee does not belong to this tenant', 403);
    }

    $employee = EmployeeModel::findById($employeeId, $station['tenant_id']);
    if (!$employee) Response::fail('Employee not found', 404);

    if ($gpsLat !== null && $gpsLng !== null && $branchLat != 0 && $branchLng != 0) {
        if (!GpsService::isWithinRange($gpsLat, $gpsLng, $branchLat, $branchLng, $gpsRadius)) {
            $distance = GpsService::distanceInMeters($gpsLat, $gpsLng, $branchLat, $branchLng);

            StationRecognitionLogModel::log(
                $station['id'], $station['branch_id'], $station['tenant_id'],
                $employeeId, $method, 'out_of_range', null,
                'Outside geofence (' . round($distance) . 'm)', null, $gpsLat, $gpsLng
            );

            Response::fail('You are outside the branch area', 403);
        }
    }
} else {
    $employeeId = (int) ($input['employee_id'] ?? 0);
    Validator::required($employeeId, 'employee_id');

    $employee = EmployeeModel::findById($employeeId, $station['tenant_id']);
    if (!$employee) Response::fail('Employee not found', 404);

    if ($gpsLat !== null && $gpsLng !== null && $branchLat != 0 && $branchLng != 0) {
        if (!GpsService::isWithinRange($gpsLat, $gpsLng, $branchLat, $branchLng, $gpsRadius)) {
            $distance = GpsService::distanceInMeters($gpsLat, $gpsLng, $branchLat, $branchLng);

            StationRecognitionLogModel::log(
                $station['id'], $station['branch_id'], $station['tenant_id'],
                $employeeId, $method, 'out_of_range', $confidence,
                'Outside geofence (' . round($distance) . 'm)', $capturedImage ? 'captured' : null, $gpsLat, $gpsLng
            );

            Response::fail('You are outside the branch area', 403);
        }
    }
}

$result = AttendanceModel::recordStationCheckInOut(
    $employeeId,
    $station['branch_id'],
    $station['tenant_id'],
    $station['id'],
    'station_' . $method,
    $confidence
);

$employeeName = $employee['name'];

StationRecognitionLogModel::log(
    $station['id'],
    $station['branch_id'],
    $station['tenant_id'],
    $employeeId,
    $method,
    $result['action'] === 'too_soon' ? 'too_soon' : 'success',
    $confidence,
    $result['message'] ?? null,
    $capturedImage ? 'captured' : null,
    $gpsLat,
    $gpsLng
);

if ($result['action'] === 'too_soon') {
    Response::fail($result['message'], 429);
}

Response::success([
    'action' => $result['action'],
    'attendance_id' => $result['attendance_id'],
    'employee_name' => $employeeName,
    'timestamp' => $result['timestamp'],
]);
