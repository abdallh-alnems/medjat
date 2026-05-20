<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$token = $_SERVER['HTTP_X_STATION_TOKEN'] ?? null;
if (!$token) Response::fail('Station token is required', 401);

$station = AttendanceStationModel::findByToken($token);
if (!$station) Response::fail('Invalid station token', 401);

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$adminPin = $input['admin_pin'] ?? null;
$employeeId = (int) ($input['employee_id'] ?? 0);

Validator::required($adminPin, 'admin_pin');
Validator::required($employeeId, 'employee_id');

$valid = AttendanceStationModel::verifyAdminPin($station['branch_id'], $adminPin);
if (!$valid) Response::fail('Invalid admin PIN', 403);

$emp = EmployeeModel::findById($employeeId, $station['tenant_id']);
if (!$emp) Response::fail('Employee not found', 404);

if (isset($input['face_embedding'])) {
    $embedding = is_array($input['face_embedding']) ? json_encode($input['face_embedding']) : $input['face_embedding'];
    BiometricModel::enrollFace($employeeId, $station['tenant_id'], $embedding, null, 0.0);
}

if (isset($input['fingerprint_template'])) {
    BiometricModel::enrollFingerprint($employeeId, $station['tenant_id'], base64_decode($input['fingerprint_template']));
}

Response::success([
    'employee_id' => $employeeId,
    'status' => BiometricModel::getStatus($employeeId, $station['tenant_id']),
], 201);
