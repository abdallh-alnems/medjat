<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'view_analytics');

$startMonth = $_GET['start_month'] ?? date('Y-m', strtotime('-11 months'));
$endMonth = $_GET['end_month'] ?? date('Y-m');
$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;
$department = $_GET['department'] ?? null;
$includeDraft = isset($_GET['include_draft']) && in_array(strtolower($_GET['include_draft']), ['1', 'true'], true);
$dimension = $_GET['dimension'] ?? null;

if ($branchId) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

if ($auth['role'] === 'branch_manager' && !empty($auth['branch_id']) && !$branchId) {
    $branchId = (int) $auth['branch_id'];
}

$dept = $department !== '' ? $department : null;

$result = [
    'labor_cost' => AnalyticsModel::laborCost($tenantId, $startMonth, $endMonth, $branchId, $dept, $includeDraft),
];

if ($dimension !== null && in_array($dimension, ['branch', 'department'], true)) {
    $result['breakdown'] = AnalyticsModel::laborCostBreakdown($tenantId, $endMonth, $dimension, $includeDraft);
}

Response::success($result);
