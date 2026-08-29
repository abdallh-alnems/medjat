<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

/**
 * The User IDs a terminal knows about, and who each one is.
 *
 * Unlinked rows come first: that list is the entire setup task after the
 * device is mounted, and it shrinks to nothing as HR works through it.
 */

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

// Readable by whoever runs attendance day to day, and by whoever set the
// devices up — a role with one permission but not the other must not hit a
// 403 on a screen it can reach.
PermissionMiddleware::checkAny($auth, ['manage_attendance', 'manage_company_settings']);

$deviceId = (int) ($_GET['device_id'] ?? 0);
Validator::required($deviceId, 'device_id');

$device = AttendanceDeviceModel::findById($deviceId, $tenantId);
if (!$device) {
    Response::notFound('Device');
}

$filter = $_GET['filter'] ?? null;
if ($filter !== null && !in_array($filter, ['linked', 'pending'], true)) {
    $filter = null;
}

$users = array_map(static function (array $u): array {
    return [
        'id' => (int) $u['id'],
        'device_user_id' => $u['device_user_id'],
        'device_name' => $u['device_name'],
        'employee_id' => $u['employee_id'] !== null ? (int) $u['employee_id'] : null,
        'employee_name' => $u['employee_name'],
        'employee_job_title' => $u['employee_job_title'],
        'card_number' => $u['card_number'],
        'is_device_admin' => $u['privilege'] !== null && (int) $u['privilege'] > 0,
        'last_punch_at' => $u['last_punch_at'],
        'linked_at' => $u['linked_at'],
        'unmatched_punches' => (int) $u['unmatched_punches'],
    ];
}, DeviceUserModel::listForDevice($deviceId, $tenantId, $filter));

Response::success([
    'device' => [
        'id' => (int) $device['id'],
        'serial_number' => $device['serial_number'],
        'name' => $device['name'],
        'branch_id' => $device['branch_id'] !== null ? (int) $device['branch_id'] : null,
    ],
    'users' => $users,
    'punch_stats' => DevicePunchModel::statsForDevice($deviceId, $tenantId),
]);
