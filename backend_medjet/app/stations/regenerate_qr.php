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

$result = AttendanceStationModel::regenerateQR($id, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'station.regenerate_qr', 'station', $id);

Response::success($result);
