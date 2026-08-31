<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_support');

$page = max(1, (int) ($_GET['page'] ?? 1));
$limit = min(50, max(1, (int) ($_GET['limit'] ?? 20)));
$status = $_GET['status'] ?? null;

$result = SupportModel::listByTenant($tenantId, $status, $page, $limit);

Response::success($result);
