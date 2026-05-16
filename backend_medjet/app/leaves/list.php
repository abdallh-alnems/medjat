<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_leaves');

$page = max(1, (int) ($_GET['page'] ?? 1));
$status = $_GET['status'] ?? null;

$result = LeaveModel::getByTenant($tenantId, $page, 20, $status);

Response::success($result);
