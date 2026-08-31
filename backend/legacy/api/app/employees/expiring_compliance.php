<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

// Detailed credential data — allow employee managers and report viewers.
PermissionMiddleware::checkAny($auth, ['manage_employees', 'view_reports']);

$days = (int) ($_GET['days'] ?? 30);
$days = max(1, min(365, $days));
$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;
$includeExpired = !isset($_GET['include_expired']) || $_GET['include_expired'] !== '0';

if ($branchId) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

$items = EmployeeModel::getExpiringCompliance($tenantId, $days, $branchId, $includeExpired);

$expiredCount = 0;
foreach ($items as $row) {
    if (!empty($row['is_expired'])) {
        $expiredCount++;
    }
}

Response::success([
    'items' => $items,
    'count' => count($items),
    'expired_count' => $expiredCount,
    'expiring_count' => count($items) - $expiredCount,
    'days' => $days,
]);
