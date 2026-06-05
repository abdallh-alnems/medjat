<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_engagement');

$input = $auth['input'];
$surveyId = (int) ($input['survey_id'] ?? 0);
$question = trim((string) ($input['question'] ?? ''));
$qtype = $input['qtype'] ?? 'rating';

Validator::required($surveyId, 'survey_id');
Validator::required($question, 'question');
$qtype = Validator::enum($qtype, SurveyModel::QTYPES, 'qtype');

$survey = SurveyModel::findById($surveyId, $tenantId);
if (!$survey) {
    Response::notFound('Survey');
}

$options = $input['options'] ?? null;
if (in_array($qtype, ['single_choice', 'multi_choice'], true) && empty($options)) {
    Response::fail('options are required for choice-type questions', 400);
}

$data = [
    'question' => $question,
    'question_ar' => $input['question_ar'] ?? null,
    'qtype' => $qtype,
    'options' => $options,
    'is_required' => $input['is_required'] ?? 1,
    'sort_order' => $input['sort_order'] ?? 0,
];

$qId = SurveyModel::addQuestion($surveyId, $tenantId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'survey.question_add', 'survey_question', $qId, ['survey_id' => $surveyId, 'qtype' => $qtype]);

Response::success(['id' => $qId, 'message' => 'Question added'], 201);
