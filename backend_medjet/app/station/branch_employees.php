<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();

$token = $_SERVER['HTTP_X_STATION_TOKEN'] ?? null;
if (!$token) Response::fail('Station token is required', 401);

$station = AttendanceStationModel::findByToken($token);
if (!$station) Response::fail('Invalid station token', 401);

$employees = Database::fetchAll(
    "SELECT id, name, phone, job_title, biometric_enrollment_status
     FROM employees
     WHERE branch_id = ? AND tenant_id = ? AND status = 'active'
     ORDER BY name ASC",
    [$station['branch_id'], $station['tenant_id']]
);

Response::success(['items' => $employees]);
