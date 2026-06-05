<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'view_analytics');

$startDate = $_GET['start_date'] ?? date('Y-m-01', strtotime('-11 months'));
$endDate = $_GET['end_date'] ?? date('Y-m-d');
$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;
$department = $_GET['department'] ?? null;

if ($branchId) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

if ($auth['role'] === 'branch_manager' && !empty($auth['branch_id']) && !$branchId) {
    $branchId = (int) $auth['branch_id'];
}

Response::success(
    AnalyticsModel::turnover($tenantId, $startDate, $endDate, $branchId, $department !== '' ? $department : null)
);
