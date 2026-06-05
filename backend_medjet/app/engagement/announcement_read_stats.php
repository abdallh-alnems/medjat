<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_engagement');

$id = (int) ($_GET['id'] ?? 0);
Validator::required($id, 'id');

$announcement = AnnouncementModel::findById($id, $tenantId);
if (!$announcement) {
    Response::notFound('Announcement');
}

$stats = AnnouncementModel::readStats($id, $tenantId);

Response::success($stats);
