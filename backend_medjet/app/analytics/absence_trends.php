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

$dept = $department !== '' ? $department : null;

Response::success([
    'start_date' => $startDate,
    'end_date' => $endDate,
    'trend' => AnalyticsModel::absenceTrend($tenantId, $startDate, $endDate, $branchId, $dept),
    'by_weekday' => AnalyticsModel::absenceByWeekday($tenantId, $startDate, $endDate, $branchId, $dept),
    'top_absentees' => AnalyticsModel::topAbsentees($tenantId, $startDate, $endDate, 10, $branchId, $dept),
]);
