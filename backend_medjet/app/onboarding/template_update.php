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

$data = [];
foreach (['title', 'title_ar', 'task_type', 'description', 'sort_order', 'is_active'] as $key) {
    if (array_key_exists($key, $input)) {
        $data[$key] = $input[$key];
    }
}

if (isset($data['task_type'])) {
    $data['task_type'] = Validator::enum($data['task_type'], OnboardingModel::TASK_TYPES, 'task_type');
}

OnboardingModel::updateTemplate($id, $tenantId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'onboarding_template.update', 'onboarding_template', $id);

Response::success(['message' => 'Template updated']);
