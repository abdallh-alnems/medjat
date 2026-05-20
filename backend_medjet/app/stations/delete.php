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

$ok = AttendanceStationModel::deactivateStation($id, $tenantId);
if (!$ok) Response::fail('Failed to delete station', 400);

AuditLogModel::log($tenantId, $auth['admin_id'], 'station.delete', 'station', $id);

Response::success(['deleted' => true]);
