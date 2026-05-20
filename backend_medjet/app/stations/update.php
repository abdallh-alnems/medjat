<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'station_manage');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
Validator::required($id, 'id');

$station = AttendanceStationModel::findById($id, $tenantId);
if (!$station) Response::fail('Station not found', 404);

$data = [];
if (isset($input['device_name'])) {
    Validator::maxLength($input['device_name'], 100, 'device_name');
    $data['device_name'] = $input['device_name'];
}
if (isset($input['is_active'])) {
    $data['is_active'] = (int) $input['is_active'];
}

if (!empty($data)) {
    AttendanceStationModel::updateStation($id, $tenantId, $data);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'station.update', 'station', $id);

Response::success(['id' => $id]);
