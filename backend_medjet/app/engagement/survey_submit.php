<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());

$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];

$input = $auth['input'];
$surveyId = (int) ($input['survey_id'] ?? 0);
$answers = $input['answers'] ?? [];

Validator::required($surveyId, 'survey_id');

if (empty($answers) || !is_array($answers)) {
    Response::fail('answers array is required', 400);
}

$responseId = SurveyModel::submitResponse($surveyId, $tenantId, $employeeId, $answers);

Response::success(['response_id' => $responseId, 'message' => 'Response submitted'], 201);
