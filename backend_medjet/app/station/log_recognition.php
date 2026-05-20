<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$token = $_SERVER['HTTP_X_STATION_TOKEN'] ?? null;
if (!$token) Response::fail('Station token is required', 401);

$station = AttendanceStationModel::findByToken($token);
if (!$station) Response::fail('Invalid station token', 401);

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$matchedEmployeeId = isset($input['matched_employee_id']) ? (int) $input['matched_employee_id'] : null;
$method = $input['method'] ?? null;
$resultVal = $input['result'] ?? null;
$confidence = isset($input['confidence']) ? (float) $input['confidence'] : null;
$failureReason = $input['failure_reason'] ?? null;

Validator::required($method, 'method');
Validator::required($resultVal, 'result');

StationRecognitionLogModel::log(
    $station['id'],
    $station['branch_id'],
    $station['tenant_id'],
    $matchedEmployeeId,
    $method,
    $resultVal,
    $confidence,
    $failureReason
);

Response::success(['logged' => true]);
