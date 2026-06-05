<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$taskId = (int) ($input['task_id'] ?? 0);
$status = $input['status'] ?? '';
Validator::required($taskId, 'task_id');
Validator::required($status, 'status');

$status = Validator::enum($status, OnboardingModel::TASK_STATUSES, 'status');

OnboardingModel::setTaskStatus($taskId, $tenantId, $status, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'onboarding_task.set_status', 'onboarding_task', $taskId, ['status' => $status]);

Response::success(['message' => 'Task status updated']);
