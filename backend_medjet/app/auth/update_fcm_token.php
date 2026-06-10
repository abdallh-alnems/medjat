<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

// Shared by both apps. The employee app sends an employee token; the management
// app sends an admin Firebase token. Authenticate by whichever is present so the
// FCM token lands in admin_devices under the right admin account.
$hasEmployeeToken = !empty($_SERVER['HTTP_X_EMPLOYEE_TOKEN'])
    || !empty($_GET['employee_token']);
if (!$hasEmployeeToken) {
    $rawInput = json_decode(file_get_contents('php://input'), true);
    $hasEmployeeToken = is_array($rawInput) && !empty($rawInput['employee_token']);
}

if ($hasEmployeeToken) {
    $auth = Auth::authenticateEmployee(db());
} else {
    $auth = Auth::authenticateUser(db());
}
$adminId = $auth['admin_id'];
$input = $auth['input'];

if (empty($adminId)) {
    Response::fail('No account linked to receive notifications', 422);
}

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

// Keep a single active token per account. Stale tokens left active here cause
// the same device to receive each push more than once.
Database::execute(
    "UPDATE admin_devices SET is_active = 0 WHERE admin_id = ? AND fcm_token <> ?",
    [$adminId, $fcmToken]
);

Response::success(['message' => 'FCM token updated']);
