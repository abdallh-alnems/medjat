<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_company_settings');

$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;
$shifts = ShiftModel::getByTenant($tenantId, $branchId);
Response::success(['items' => $shifts]);
