<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

OnboardingModel::ensureDefaults($tenantId);
$count = OnboardingModel::generateForEmployee($tenantId, $employeeId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'onboarding.generate', 'employee', $employeeId, ['tasks_generated' => $count]);

Response::success(['employee_id' => $employeeId, 'tasks_generated' => $count, 'message' => 'Onboarding tasks generated']);
