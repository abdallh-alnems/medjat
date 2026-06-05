<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_engagement');

$input = $auth['input'];
$title = trim((string) ($input['title'] ?? ''));
Validator::required($title, 'title');

$type = Validator::enum($input['type'] ?? 'custom', SurveyModel::TYPES, 'type');
$audienceType = Validator::enum($input['audience_type'] ?? 'all', SurveyModel::AUDIENCE_TYPES, 'audience_type');
$audienceId = ($input['audience_id'] ?? null) !== null ? (int) $input['audience_id'] : null;

if ($audienceType !== 'all' && $audienceId === null) {
    Response::fail('audience_id is required when audience_type is not "all"', 400);
}

$data = [
    'title' => $title,
    'title_ar' => $input['title_ar'] ?? null,
    'description' => $input['description'] ?? null,
    'type' => $type,
    'is_anonymous' => $input['is_anonymous'] ?? 1,
    'audience_type' => $audienceType,
    'audience_id' => $audienceId,
    'start_date' => $input['start_date'] ?? null,
    'end_date' => $input['end_date'] ?? null,
];

$id = SurveyModel::create($tenantId, $data, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'survey.create', 'survey', $id, ['title' => $title, 'type' => $type]);

Response::success(['id' => $id, 'message' => 'Survey created'], 201);
