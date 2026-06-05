<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_engagement');

$input = $auth['input'];
$title = trim((string) ($input['title'] ?? ''));
$body = trim((string) ($input['body'] ?? ''));
Validator::required($title, 'title');
Validator::required($body, 'body');

$category = Validator::enum($input['category'] ?? 'general', AnnouncementModel::CATEGORIES, 'category');
$audienceType = Validator::enum($input['audience_type'] ?? 'all', AnnouncementModel::AUDIENCE_TYPES, 'audience_type');
$audienceId = ($input['audience_id'] ?? null) !== null ? (int) $input['audience_id'] : null;

if ($audienceType !== 'all' && $audienceId === null) {
    Response::fail('audience_id is required when audience_type is not "all"', 400);
}

if ($audienceType === 'branch' && $audienceId !== null) {
    PermissionMiddleware::checkBranchAccess($auth, $audienceId);
    $branch = BranchModel::findById($audienceId, $tenantId);
    if (!$branch) {
        Response::notFound('Branch');
    }
}

if ($audienceType === 'category' && $audienceId !== null) {
    $cat = Database::fetchOne(
        "SELECT id FROM employee_categories WHERE id = ? AND tenant_id = ?",
        [$audienceId, $tenantId]
    );
    if (!$cat) {
        Response::notFound('Employee category');
    }
}

if ($audienceType === 'employee' && $audienceId !== null) {
    $emp = EmployeeModel::findById($audienceId, $tenantId);
    if (!$emp) {
        Response::notFound('Employee');
    }
}

$data = [
    'title' => $title,
    'title_ar' => $input['title_ar'] ?? null,
    'body' => $body,
    'body_ar' => $input['body_ar'] ?? null,
    'category' => $category,
    'audience_type' => $audienceType,
    'audience_id' => $audienceId,
    'is_pinned' => isset($input['is_pinned']) ? (int) $input['is_pinned'] : 0,
];

$id = AnnouncementModel::create($tenantId, $data, $auth['admin_id']);

$shouldPublish = !empty($input['publish']) || ($input['status'] ?? '') === 'published';
if ($shouldPublish) {
    $announcement = AnnouncementModel::findById($id, $tenantId);
    if ($announcement && $announcement['published_at'] === null) {
        AnnouncementModel::setStatus($id, $tenantId, 'published');
        $empIds = AnnouncementModel::resolveAudienceEmployeeIds($tenantId, $audienceType, $audienceId);
        if (!empty($empIds)) {
            AnnouncementModel::broadcastNotifications($tenantId, $id, $title, $input['title_ar'] ?? null, mb_substr($body, 0, 120), $input['body_ar'] ?? null, $empIds);
        }
        AuditLogModel::log($tenantId, $auth['admin_id'], 'announcement.published', 'announcement', $id, ['reached' => count($empIds)]);
    }
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'announcement.create', 'announcement', $id, ['title' => $title, 'audience_type' => $audienceType]);

Response::success(['id' => $id, 'message' => 'Announcement created'], 201);
