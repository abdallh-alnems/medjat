<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$employeeId = (int) ($_GET['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$tasks = OnboardingModel::listForEmployee($tenantId, $employeeId);
$progress = OnboardingModel::progress($tenantId, $employeeId);

Response::success([
    'employee_id' => $employeeId,
    'tasks' => $tasks,
    'progress' => $progress,
]);
