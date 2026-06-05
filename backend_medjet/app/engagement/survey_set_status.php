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
$status = Validator::enum($status, SurveyModel::STATUSES, 'status');

$survey = SurveyModel::findById($id, $tenantId);
if (!$survey) {
    Response::notFound('Survey');
}

$wasActive = $survey['status'] === 'active';

SurveyModel::setStatus($id, $tenantId, $status);

if ($status === 'active' && !$wasActive) {
    $audienceId = $survey['audience_id'] ? (int) $survey['audience_id'] : null;
    $empIds = SurveyModel::resolveAudienceEmployeeIds($tenantId, $survey['audience_type'], $audienceId);
    if (!empty($empIds)) {
        SurveyModel::broadcastNotifications(
            $tenantId,
            $id,
            $survey['title'],
            $survey['title_ar'],
            $empIds
        );
    }
    AuditLogModel::log($tenantId, $auth['admin_id'], 'survey.activated', 'survey', $id, ['reached' => count($empIds)]);
} else {
    AuditLogModel::log($tenantId, $auth['admin_id'], 'survey.set_status', 'survey', $id, ['status' => $status]);
}

Response::success(['message' => 'Survey status updated']);
