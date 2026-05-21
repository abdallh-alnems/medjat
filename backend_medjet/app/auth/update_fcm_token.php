<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$auth = Auth::authenticateUser(db());
$adminId = $auth['admin_id'];
$input = $auth['input'];

$fcmToken = $input['fcm_token'] ?? null;
$platform = $input['platform'] ?? 'android';
$deviceId = $input['device_id'] ?? null;

if (empty($fcmToken)) {
    Response::fail('fcm_token is required', 400);
}

$existing = Database::fetchOne(
    "SELECT id FROM admin_devices WHERE admin_id = ? AND fcm_token = ? LIMIT 1",
    [$adminId, $fcmToken]
);

if ($existing) {
    Database::execute(
        "UPDATE admin_devices SET is_active = 1, platform = ?, device_id = ?, updated_at = NOW() WHERE id = ?",
        [$platform, $deviceId, $existing['id']]
    );
} else {
    Database::execute(
        "INSERT INTO admin_devices (admin_id, fcm_token, platform, device_id, is_active)
         VALUES (?, ?, ?, ?, 1)
         ON DUPLICATE KEY UPDATE fcm_token = VALUES(fcm_token), platform = VALUES(platform), is_active = 1, updated_at = NOW()",
        [$adminId, $fcmToken, $platform, $deviceId]
    );
}

Response::success(['message' => 'FCM token updated']);
