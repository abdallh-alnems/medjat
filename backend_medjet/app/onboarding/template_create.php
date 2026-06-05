<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$title = trim((string) ($input['title'] ?? ''));
Validator::required($title, 'title');

$taskType = Validator::enum($input['task_type'] ?? 'generic', OnboardingModel::TASK_TYPES, 'task_type');

$data = [
    'title' => $title,
    'title_ar' => $input['title_ar'] ?? null,
    'task_type' => $taskType,
    'description' => $input['description'] ?? null,
    'sort_order' => (int) ($input['sort_order'] ?? 0),
    'is_active' => isset($input['is_active']) ? (int) $input['is_active'] : 1,
];

$id = OnboardingModel::createTemplate($tenantId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'onboarding_template.create', 'onboarding_template', $id, ['title' => $title]);

Response::success(['id' => $id, 'message' => 'Template created'], 201);
