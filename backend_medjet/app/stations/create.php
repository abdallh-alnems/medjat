<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'station_manage');

$input = $auth['input'];
$branchId = (int) ($input['branch_id'] ?? 0);
$deviceName = $input['device_name'] ?? null;
$adminPin = $input['admin_pin'] ?? null;

Validator::required($branchId, 'branch_id');
Validator::required($deviceName, 'device_name');
Validator::required($adminPin, 'admin_pin');
Validator::maxLength($deviceName, 100, 'device_name');

PermissionMiddleware::checkBranchAccess($auth, $branchId);

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch) Response::fail('Branch not found', 404);

$result = AttendanceStationModel::createStation($branchId, $tenantId, $deviceName, $auth['admin_id'], $adminPin);

AuditLogModel::log($tenantId, $auth['admin_id'], 'station.create', 'station', $result['id']);

Response::success($result, 201);
