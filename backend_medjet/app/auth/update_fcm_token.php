<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();

$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$input = $auth['input'];
$fcmToken = $input['fcm_token'] ?? null;
$platform = $input['platform'] ?? 'android';
$deviceId = $input['device_id'] ?? 'unknown';

if ($fcmToken) {
    AdminModel::updateFcmToken($auth['admin_id'], $fcmToken, $platform, $deviceId);
}

Response::success(['message' => 'Token updated']);
