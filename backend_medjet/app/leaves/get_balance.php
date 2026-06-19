<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$employeeIdParam = (int) ($_GET['employee_id'] ?? 0);
if ($employeeIdParam > 0) {
    PermissionMiddleware::check($auth, 'manage_leaves');
    $employee = EmployeeModel::findById($employeeIdParam, $tenantId);
} else {
    $employee = EmployeeModel::findByAdminId($auth['admin_id'], $tenantId);
}
if (!$employee) {
    Response::fail('Employee profile not found', 404, 'employee_profile_not_found');
}

$year = (int) ($_GET['year'] ?? date('Y'));
$balance = LeaveModel::getBalance($employee['id'], $tenantId, $year);

Response::success($balance);
