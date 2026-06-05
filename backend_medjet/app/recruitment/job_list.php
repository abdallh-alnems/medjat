<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_recruitment');

$status = $_GET['status'] ?? null;

$list = JobOpeningModel::listByTenant($tenantId, $status);

Response::success(['items' => $list]);
