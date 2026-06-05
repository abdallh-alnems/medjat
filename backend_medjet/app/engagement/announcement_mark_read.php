<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());

$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];
$branchId = $auth['branch_id'];

$input = $auth['input'];
$announcementId = (int) ($input['announcement_id'] ?? 0);
Validator::required($announcementId, 'announcement_id');

$announcement = AnnouncementModel::findById($announcementId, $tenantId);
if (!$announcement) {
    Response::notFound('Announcement');
}

if ($announcement['status'] !== 'published') {
    Response::fail('Announcement is not published', 400);
}

$audienceType = $announcement['audience_type'];
$audienceId = $announcement['audience_id'] ? (int) $announcement['audience_id'] : null;
$targetIds = AnnouncementModel::resolveAudienceEmployeeIds($tenantId, $audienceType, $audienceId);

if (!in_array($employeeId, $targetIds)) {
    Response::forbidden('This announcement is not addressed to you');
}

AnnouncementModel::markRead($announcementId, $tenantId, $employeeId);

Response::success(['message' => 'Marked as read']);
