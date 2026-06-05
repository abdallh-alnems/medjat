<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_performance');

$status = $_GET['status'] ?? null;
if ($status !== null) {
    $status = Validator::enum($status, PerformanceCycleModel::STATUSES, 'status');
}

$cycles = PerformanceCycleModel::listByTenant($tenantId, $status);

Response::success(['items' => $cycles]);
