<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_schedule');

$branchId = isset($_GET['branch_id']) ? (int) $_GET['branch_id'] : null;
if ($branchId !== null) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

$swaps = ShiftSwapModel::listPendingManager($tenantId, $branchId);

Response::success(['swaps' => $swaps]);
