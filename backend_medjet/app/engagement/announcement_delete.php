<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_engagement');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
Validator::required($id, 'id');

$announcement = AnnouncementModel::findById($id, $tenantId);
if (!$announcement) {
    Response::notFound('Announcement');
}

$deleted = AnnouncementModel::delete($id, $tenantId);
if (!$deleted) {
    Response::fail('Failed to delete announcement', 500);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'announcement.delete', 'announcement', $id, ['title' => $announcement['title']]);

Response::success(['message' => 'Announcement deleted']);
