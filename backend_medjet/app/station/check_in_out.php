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
$employeeId = (int) ($input['employee_id'] ?? 0);
$method = $input['method'] ?? null;
$confidence = isset($input['confidence']) ? (float) $input['confidence'] : null;
$gpsLat = isset($input['gps_lat']) ? (float) $input['gps_lat'] : null;
$gpsLng = isset($input['gps_lng']) ? (float) $input['gps_lng'] : null;
$capturedImage = $input['captured_image_base64'] ?? null;

Validator::required($employeeId, 'employee_id');
Validator::required($method, 'method');
Validator::enum($method, ['face', 'fingerprint', 'both'], 'method');

$employee = EmployeeModel::findById($employeeId, $station['tenant_id']);
if (!$employee) Response::fail('Employee not found', 404);

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
