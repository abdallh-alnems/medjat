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

if ($announcement['audience_type'] === 'branch' && $announcement['audience_id']) {
    PermissionMiddleware::checkBranchAccess($auth, (int) $announcement['audience_id']);
}

$data = [];
if (isset($input['title'])) {
    $data['title'] = trim((string) $input['title']);
    Validator::required($data['title'], 'title');
}
if (array_key_exists('title_ar', $input)) {
    $data['title_ar'] = $input['title_ar'];
}
if (isset($input['body'])) {
    $data['body'] = trim((string) $input['body']);
    Validator::required($data['body'], 'body');
}
if (array_key_exists('body_ar', $input)) {
    $data['body_ar'] = $input['body_ar'];
}
if (isset($input['category'])) {
    $data['category'] = Validator::enum($input['category'], AnnouncementModel::CATEGORIES, 'category');
}
if (isset($input['audience_type'])) {
    $data['audience_type'] = Validator::enum($input['audience_type'], AnnouncementModel::AUDIENCE_TYPES, 'audience_type');
}
if (array_key_exists('audience_id', $input)) {
    $data['audience_id'] = $input['audience_id'] !== null ? (int) $input['audience_id'] : null;
}
if (array_key_exists('is_pinned', $input)) {
    $data['is_pinned'] = (int) $input['is_pinned'];
}

AnnouncementModel::update($id, $tenantId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'announcement.update', 'announcement', $id, $data);

Response::success(['message' => 'Announcement updated']);
