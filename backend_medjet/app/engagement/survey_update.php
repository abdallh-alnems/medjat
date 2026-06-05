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

$survey = SurveyModel::findById($id, $tenantId);
if (!$survey) {
    Response::notFound('Survey');
}

if ($survey['status'] !== 'draft') {
    Response::fail('Only draft surveys can be updated', 422);
}

$data = [];
$allowed = ['title', 'title_ar', 'description', 'type', 'is_anonymous', 'audience_type', 'audience_id', 'start_date', 'end_date'];
foreach ($allowed as $key) {
    if (array_key_exists($key, $input)) {
        $data[$key] = $input[$key];
    }
}
if (isset($data['type'])) {
    $data['type'] = Validator::enum($data['type'], SurveyModel::TYPES, 'type');
}
if (isset($data['audience_type'])) {
    $data['audience_type'] = Validator::enum($data['audience_type'], SurveyModel::AUDIENCE_TYPES, 'audience_type');
}

SurveyModel::update($id, $tenantId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'survey.update', 'survey', $id, $data);

Response::success(['message' => 'Survey updated']);
