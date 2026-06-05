<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_engagement');

$status = $_GET['status'] ?? null;
if ($status !== null) {
    $status = Validator::enum($status, AnnouncementModel::STATUSES, 'status');
}

$items = AnnouncementModel::listForAdmin($tenantId, $status);

Response::success(['items' => $items]);
