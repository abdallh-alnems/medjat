<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$month = $_GET['month'] ?? date('Y-m');
$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;
$page = max(1, (int) ($_GET['page'] ?? 1));

$result = PayrollModel::getSlipsByMonth($tenantId, $month, $branchId, $page);

Response::success($result);
