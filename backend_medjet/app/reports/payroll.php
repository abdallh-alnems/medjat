<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'view_reports');

$month = $_GET['month'] ?? date('Y-m');
$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;

if ($branchId) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

$items = PayrollModel::getReportByMonth($tenantId, $month, $branchId);
$summary = PayrollModel::getReportSummary($tenantId, $month, $branchId);

Response::success([
    'month' => $month,
    'items' => $items,
    'summary' => $summary,
]);
