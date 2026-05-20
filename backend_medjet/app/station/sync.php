<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();

$token = $_SERVER['HTTP_X_STATION_TOKEN'] ?? null;
if (!$token) Response::fail('Station token is required', 401);

$station = AttendanceStationModel::findByToken($token);
if (!$station) Response::fail('Invalid station token', 401);
if ($station['is_locked']) Response::fail('Station is locked: ' . ($station['locked_reason'] ?? ''), 403);

$syncData = AttendanceStationModel::getSyncData($station['id'], $station['tenant_id']);

Database::execute(
    "UPDATE attendance_stations SET last_sync_at = NOW() WHERE id = ?",
    [$station['id']]
);

Response::success($syncData);
