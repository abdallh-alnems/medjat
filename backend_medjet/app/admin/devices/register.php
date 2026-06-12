<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$admin = AdminAuth::require('admin');

$input = json_decode(file_get_contents('php://input'), true) ?? [];
$fcmToken = trim($input['fcm_token'] ?? '');
$platform = trim($input['platform'] ?? 'android');
$deviceId = trim($input['device_id'] ?? '');
$deviceModel = trim($input['device_model'] ?? '');
$appVersion = trim($input['app_version'] ?? '');

Validator::required($fcmToken, 'fcm_token');

$adminId = (int) $admin['admin_id'];

if (empty($deviceId)) {
    $deviceId = 'default_' . $adminId;
}

$existing = Database::fetchOne(
    "SELECT id FROM super_admin_devices WHERE admin_id = ? AND device_id = ?",
    [$adminId, $deviceId]
);

if ($existing) {
    Database::execute(
        "UPDATE super_admin_devices
         SET fcm_token = ?, platform = ?, device_model = ?, app_version = ?, is_active = 1, updated_at = NOW()
         WHERE admin_id = ? AND device_id = ?",
        [$fcmToken, $platform, $deviceModel, $appVersion, $adminId, $deviceId]
    );
} else {
    Database::execute(
        "INSERT INTO super_admin_devices (admin_id, fcm_token, platform, device_id, device_model, app_version)
         VALUES (?, ?, ?, ?, ?, ?)",
        [$adminId, $fcmToken, $platform, $deviceId, $deviceModel, $appVersion]
    );
}

Response::success(['registered' => true]);
