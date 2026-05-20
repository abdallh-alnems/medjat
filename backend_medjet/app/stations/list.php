<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'station_manage');

$branchId = isset($_GET['branch_id']) ? (int) $_GET['branch_id'] : null;

if ($branchId) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
    $stations = AttendanceStationModel::getStationsByBranch($branchId, $tenantId);
} else {
    $stations = AttendanceStationModel::getAllStations($tenantId);
}

Response::success(['items' => $stations]);
