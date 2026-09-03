<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

/**
 * Links a terminal User ID to a Permedjat employee (or unlinks it).
 *
 * Linking replays the punches that arrived before the link existed. Without
 * that, the first day of a new device — the day everyone is enrolled and
 * everyone taps — would be lost while HR is still matching names to numbers.
 */

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_attendance');

$input = $auth['input'];
$deviceUserRowId = (int) ($input['device_user_row_id'] ?? 0);
Validator::required($deviceUserRowId, 'device_user_row_id');

$row = DeviceUserModel::findById($deviceUserRowId, $tenantId);
if (!$row) {
    Response::notFound('Device user');
}

$device = AttendanceDeviceModel::findById((int) $row['device_id'], $tenantId);
if (!$device) {
    Response::notFound('Device');
}

// employee_id null means "unlink".
$employeeId = array_key_exists('employee_id', $input) && $input['employee_id'] !== null
    ? (int) $input['employee_id']
    : null;

if ($employeeId !== null) {
    $employee = EmployeeModel::findById($employeeId, $tenantId);
    if (!$employee) {
        Response::notFound('Employee');
    }

    // One fingerprint per person per device. Two User IDs pointing at the same
    // employee would fight over the same attendance row all day.
    if (DeviceUserModel::employeeTakenOnDevice((int) $row['device_id'], $employeeId, $deviceUserRowId)) {
        Response::fail(
            'This employee is already linked to another User ID on this device',
            409,
            'EMPLOYEE_ALREADY_LINKED'
        );
    }
}

DeviceUserModel::link($deviceUserRowId, $tenantId, $employeeId, $auth['admin_id']);

$replayed = ['applied' => 0, 'duplicate' => 0, 'ignored' => 0, 'failed' => 0, 'unmatched' => 0];
if ($employeeId !== null) {
    $device['tenant_id'] = $tenantId;
    $replayed = DevicePunchIngestor::replayForDeviceUser($device, $row['device_user_id']);
}

AuditLogModel::log(
    $tenantId,
    $auth['admin_id'],
    $employeeId === null ? 'device.unlink_user' : 'device.link_user',
    'employee',
    $employeeId,
    [
        'device_id' => (int) $row['device_id'],
        'device_user_id' => $row['device_user_id'],
    ]
);

Response::success([
    'message' => $employeeId === null ? 'User unlinked' : 'User linked',
    'replayed' => $replayed,
]);
