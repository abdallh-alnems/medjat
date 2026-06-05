<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_engagement');

$days = min(365, max(1, (int) ($_GET['days'] ?? 90)));
$limit = min(50, max(1, (int) ($_GET['limit'] ?? 10)));

$items = KudosModel::leaderboard($tenantId, $days, $limit);

Response::success(['items' => $items]);
