<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_engagement');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
$status = $input['status'] ?? '';
Validator::required($id, 'id');
Validator::required($status, 'status');
$status = Validator::enum($status, AnnouncementModel::STATUSES, 'status');

$announcement = AnnouncementModel::findById($id, $tenantId);
if (!$announcement) {
    Response::notFound('Announcement');
}

if ($announcement['audience_type'] === 'branch' && $announcement['audience_id']) {
    PermissionMiddleware::checkBranchAccess($auth, (int) $announcement['audience_id']);
}

$wasAlreadyPublished = $announcement['published_at'] !== null;

AnnouncementModel::setStatus($id, $tenantId, $status);

if ($status === 'published' && !$wasAlreadyPublished) {
    $audienceId = $announcement['audience_id'] ? (int) $announcement['audience_id'] : null;
    $empIds = AnnouncementModel::resolveAudienceEmployeeIds($tenantId, $announcement['audience_type'], $audienceId);
    if (!empty($empIds)) {
        AnnouncementModel::broadcastNotifications(
            $tenantId,
            $id,
            $announcement['title'],
            $announcement['title_ar'],
            mb_substr($announcement['body'], 0, 120),
            $announcement['body_ar'],
            $empIds
        );
    }
    AuditLogModel::log($tenantId, $auth['admin_id'], 'announcement.published', 'announcement', $id, ['reached' => count($empIds)]);
} else {
    AuditLogModel::log($tenantId, $auth['admin_id'], 'announcement.set_status', 'announcement', $id, ['status' => $status]);
}

Response::success(['message' => 'Announcement status updated']);
