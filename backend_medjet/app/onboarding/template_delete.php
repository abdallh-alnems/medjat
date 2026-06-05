<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
Validator::required($id, 'id');

$deleted = OnboardingModel::deleteTemplate($id, $tenantId);
if (!$deleted) {
    Response::notFound('Template');
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'onboarding_template.delete', 'onboarding_template', $id);

Response::success(['message' => 'Template deleted']);
