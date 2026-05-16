<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'view_reports');

$page = max(1, (int) ($_GET['page'] ?? 1));
$result = WarningModel::getByTenant($tenantId, $page);

Response::success($result);
