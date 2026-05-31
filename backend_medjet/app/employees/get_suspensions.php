<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$employeeId = (int) ($_GET['employee_id'] ?? 0);
if ($employeeId <= 0) {
    Response::fail('employee_id is required', 422);
}

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

// Auto-reactivate this employee if a definite suspension has elapsed.
EmployeeSuspensionModel::reconcileExpired($tenantId, date('Y-m-d'));

$suspensions = EmployeeSuspensionModel::getByEmployee($employeeId, $tenantId);
$active = EmployeeSuspensionModel::getActiveForEmployee($employeeId, $tenantId);

Response::success([
    'suspensions' => $suspensions,
    'active' => $active,
]);
