<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'view_reports');

$startDate = $_GET['start_date'] ?? date('Y-m-01');
$endDate = $_GET['end_date'] ?? date('Y-m-d');
$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;

if ($branchId) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

$employees = AttendanceModel::getReportByRange($tenantId, $startDate, $endDate, $branchId);
$summary = AttendanceModel::getReportSummary($tenantId, $startDate, $endDate, $branchId);

Response::success([
    'start_date' => $startDate,
    'end_date' => $endDate,
    'items' => $employees,
    'summary' => $summary,
]);
