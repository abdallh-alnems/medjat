<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_engagement');

$input = $auth['input'];
$questionId = (int) ($input['question_id'] ?? 0);
Validator::required($questionId, 'question_id');

$data = [];
$allowed = ['question', 'question_ar', 'qtype', 'options', 'is_required', 'sort_order'];
foreach ($allowed as $key) {
    if (array_key_exists($key, $input)) {
        $data[$key] = $input[$key];
    }
}
if (isset($data['qtype'])) {
    $data['qtype'] = Validator::enum($data['qtype'], SurveyModel::QTYPES, 'qtype');
}

SurveyModel::updateQuestion($questionId, $tenantId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'survey.question_update', 'survey_question', $questionId, $data);

Response::success(['message' => 'Question updated']);
