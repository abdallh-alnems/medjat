<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

/**
 * Claims a terminal by its serial number and binds it to one branch.
 *
 * The serial is printed on the back of the device, so whoever is standing next
 * to it can claim it. First claim wins and locks the serial to that company —
 * a second company entering the same serial is refused rather than quietly
 * taking over another company's punch stream.
 */

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$serial = AttendanceDeviceModel::normaliseSerial($input['serial_number'] ?? '');
$branchId = (int) ($input['branch_id'] ?? 0);
$name = isset($input['name']) && trim((string) $input['name']) !== ''
    ? Validator::maxLength(trim((string) $input['name']), 100, 'name')
    : null;

Validator::required($serial, 'serial_number');
Validator::required($branchId, 'branch_id');

if (!preg_match('/^[A-Z0-9\-]{4,64}$/', $serial)) {
    Response::fail('Serial number looks invalid', 422, 'INVALID_SERIAL');
}

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch) {
    Response::notFound('Branch');
}

$device = AttendanceDeviceModel::claim($serial, $tenantId, $branchId, $name, $auth['admin_id']);

// Anything the device sent before it was claimed belongs to this company now:
// its user list, and any punches from the day it was mounted.
Database::execute(
    "UPDATE device_users SET tenant_id = ? WHERE device_id = ? AND tenant_id IS NULL",
    [$tenantId, (int) $device['id']]
);
$adopted = DevicePunchModel::adoptOrphans((int) $device['id'], $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'device.register', 'device', (int) $device['id'], [
    'serial_number' => $serial,
    'branch_id' => $branchId,
]);

$isOnline = AttendanceDeviceModel::isOnline($device['last_seen_at']);

Response::success([
    'message' => 'Device registered',
    'device' => [
        'id' => (int) $device['id'],
        'serial_number' => $device['serial_number'],
        'name' => $device['name'],
        'branch_id' => (int) $device['branch_id'],
        'status' => $device['status'],
        'is_online' => $isOnline,
        'last_seen_at' => $device['last_seen_at'],
    ],
    // The device has to reach us before anything works, so say plainly whether
    // it already has. "Never contacted" means the serial is right but the
    // terminal still needs its server address set.
    'has_contacted_server' => $device['first_seen_at'] !== null,
    'adopted_punches' => $adopted,
]);
