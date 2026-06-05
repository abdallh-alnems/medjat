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

SurveyModel::deleteQuestion($questionId, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'survey.question_delete', 'survey_question', $questionId);

Response::success(['message' => 'Question deleted']);
