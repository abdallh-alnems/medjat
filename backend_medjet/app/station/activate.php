<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$qrPayload = $input['qr_payload'] ?? null;
Validator::required($qrPayload, 'qr_payload');

$deviceInfo = $input['device_info'] ?? [];

$result = AttendanceStationModel::activateStation($qrPayload, $deviceInfo);
if (!$result) {
    Response::fail('Invalid or expired QR code', 400);
}

Response::success($result);
