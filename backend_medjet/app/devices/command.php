<?php
require_once __DIR__ . '/../../config/bootstrap.php';

/**
 * Queues a command for a terminal to collect on its next poll (a few seconds).
 *
 * We never dial the device — it lives behind the customer's router — so every
 * instruction waits here until the device asks for it.
 */

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$deviceId = (int) ($input['device_id'] ?? 0);
$kind = (string) ($input['kind'] ?? '');

Validator::required($deviceId, 'device_id');
Validator::enum($kind, DeviceCommandModel::KINDS, 'kind');

$device = AttendanceDeviceModel::findById($deviceId, $tenantId);
if (!$device) {
    Response::notFound('Device');
}

// Company local time, read from MySQL rather than PHP (which runs in UTC) —
// sending a UTC clock to the terminal would shift every punch by the offset.
$payload = ZktecoAdms::commandPayload($kind, ['now' => DevicePunchIngestor::now()]);
if ($payload === null) {
    Response::fail('Unsupported command', 422, 'UNSUPPORTED_COMMAND');
}

$commandId = DeviceCommandModel::queue($tenantId, $deviceId, $kind, $payload, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'device.command', 'device', $deviceId, ['kind' => $kind]);

Response::success([
    'message' => 'Command queued',
    'command_id' => $commandId,
    'recent' => DeviceCommandModel::listForDevice($deviceId, $tenantId, 10),
]);
