<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_engagement');

$limit = min(50, max(1, (int) ($_GET['limit'] ?? 50)));
$beforeId = isset($_GET['before_id']) ? (int) $_GET['before_id'] : null;

$items = KudosModel::wall($tenantId, $limit, $beforeId);

Response::success(['items' => $items]);
