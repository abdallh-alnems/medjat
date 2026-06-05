<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_engagement');

$id = (int) ($_GET['id'] ?? 0);
Validator::required($id, 'id');

$survey = SurveyModel::findById($id, $tenantId);
if (!$survey) {
    Response::notFound('Survey');
}

$results = SurveyModel::results($id, $tenantId);

Response::success($results);
