<?php
require_once __DIR__ . '/../../config/bootstrap.php';

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

$fields = [];

if (array_key_exists('name', $input)) {
    $name = trim((string) $input['name']);
    $fields['name'] = $name === '' ? null : Validator::maxLength($name, 100, 'name');
}

if (array_key_exists('branch_id', $input)) {
    $branchId = (int) $input['branch_id'];
    if (!BranchModel::findById($branchId, $tenantId)) {
        Response::notFound('Branch');
    }
    $fields['branch_id'] = $branchId;
}

if (array_key_exists('status', $input)) {
    // 'unclaimed' is not settable here — releasing a device is delete.php, so
    // that the users and queued commands are cleaned up with it.
    $fields['status'] = Validator::enum((string) $input['status'], ['active', 'disabled'], 'status');
}

if (array_key_exists('direction_mode', $input)) {
    $fields['direction_mode'] = Validator::enum(
        (string) $input['direction_mode'],
        ['auto', 'device_status'],
        'direction_mode'
    );
}

if (array_key_exists('min_interval_seconds', $input)) {
    $interval = (int) $input['min_interval_seconds'];
    if ($interval < 0 || $interval > 3600) {
        Response::fail('min_interval_seconds must be between 0 and 3600', 422, 'min_interval_range');
    }
    $fields['min_interval_seconds'] = $interval;
}

if (array_key_exists('clock_offset_minutes', $input)) {
    $offset = (int) $input['clock_offset_minutes'];
    if ($offset < -720 || $offset > 720) {
        Response::fail('clock_offset_minutes must be between -720 and 720', 422, 'clock_offset_range');
    }
    $fields['clock_offset_minutes'] = $offset;
}

foreach (['keep_unmatched', 'debug_logging'] as $flag) {
    if (array_key_exists($flag, $input)) {
        $value = filter_var($input[$flag], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($value === null) {
            Response::fail($flag . ' must be true or false', 422, $flag . '_bool');
        }
        $fields[$flag] = $value ? 1 : 0;
    }
}

if (!$fields) {
    Response::fail('Nothing to update', 400, 'NO_FIELDS');
}

AttendanceDeviceModel::update($deviceId, $tenantId, $fields);

AuditLogModel::log($tenantId, $auth['admin_id'], 'device.update', 'device', $deviceId, array_keys($fields));

Response::success(['message' => 'Device updated']);
