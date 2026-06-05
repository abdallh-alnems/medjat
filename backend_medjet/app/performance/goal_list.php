<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_performance');

$employeeId = (int) ($_GET['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

PermissionMiddleware::checkBranchAccess($auth, $employee['branch_id'] ?? null);

$cycleId = isset($_GET['cycle_id']) ? (int) $_GET['cycle_id'] : null;

$goals = PerformanceGoalModel::listByEmployee($tenantId, $employeeId, $cycleId);
$summary = PerformanceGoalModel::summary($tenantId, $employeeId, $cycleId);

Response::success(['items' => $goals, 'summary' => $summary]);
