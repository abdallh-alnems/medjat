<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$title = trim((string) ($input['title'] ?? ''));
Validator::required($employeeId, 'employee_id');
Validator::required($title, 'title');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$taskType = Validator::enum($input['task_type'] ?? 'generic', OnboardingModel::TASK_TYPES, 'task_type');

$data = [
    'title' => $title,
    'task_type' => $taskType,
    'sort_order' => (int) ($input['sort_order'] ?? 0),
];

$id = OnboardingModel::addTask($tenantId, $employeeId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'onboarding_task.add', 'onboarding_task', $id, ['employee_id' => $employeeId, 'title' => $title]);

Response::success(['id' => $id, 'message' => 'Task added'], 201);
