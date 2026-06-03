<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$token = $_SERVER['HTTP_X_STATION_TOKEN'] ?? null;
if (!$token) Response::fail('Station token is required', 401);

$station = AttendanceStationModel::findByToken($token);
if (!$station) Response::fail('Invalid station token', 401);

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$pin = $input['pin'] ?? null;
Validator::required($pin, 'pin');

$otpValid = KioskPinModel::verify((int) $station['id'], $pin);
Response::success(['valid' => $otpValid]);
