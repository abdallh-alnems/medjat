<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'view_reports');

$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;

if ($branchId) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

$items = EmployeeModel::getReport($tenantId, $branchId);
$summary = EmployeeModel::getReportSummary($tenantId, $branchId);

Response::success([
    'items' => $items,
    'summary' => $summary,
]);
