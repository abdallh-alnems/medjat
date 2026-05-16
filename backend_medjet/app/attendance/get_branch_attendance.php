<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_attendance');

$date = $_GET['date'] ?? date('Y-m-d');
$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;

if ($branchId) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

$records = AttendanceModel::getByDate($tenantId, $date, $branchId);

Response::success([
    'records' => $records,
    'date' => $date,
]);
