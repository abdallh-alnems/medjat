<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_performance');
$input = $auth['input'];

$id = (int) ($input['id'] ?? 0);
Validator::required($id, 'id');

$goal = PerformanceGoalModel::findById($id, $tenantId);
if (!$goal) {
    Response::notFound('Goal');
}

$employee = EmployeeModel::findById((int) $goal['employee_id'], $tenantId);
if ($employee) {
    PermissionMiddleware::checkBranchAccess($auth, $employee['branch_id'] ?? null);
}

PerformanceGoalModel::delete($id, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'performance_goal.delete', 'performance_goal', $id);

Response::success(['message' => 'Goal deleted']);
