<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_leaves');

$status = isset($_GET['status']) && $_GET['status'] !== '' ? (string) $_GET['status'] : null;
$limit = min(1000, max(1, (int) ($_GET['limit'] ?? 200)));

Response::success([
    'encashments' => LeaveEncashmentModel::listForTenant($tenantId, $status, $limit),
]);
