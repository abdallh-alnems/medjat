<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

/**
 * Releases a device back to unclaimed.
 *
 * The attendance already recorded from it stays: those hours were worked, and
 * they belong to the company, not to the hardware. What goes is the link — the
 * User ID mapping and any queued commands — so the terminal can be moved to
 * another branch or sold on without carrying someone else's people with it.
 */

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$deviceId = (int) ($input['device_id'] ?? 0);
Validator::required($deviceId, 'device_id');

$device = AttendanceDeviceModel::findById($deviceId, $tenantId);
if (!$device) {
    Response::notFound('Device');
}

AttendanceDeviceModel::release($deviceId, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'device.release', 'device', $deviceId, [
    'serial_number' => $device['serial_number'],
]);

Response::success(['message' => 'Device released']);
