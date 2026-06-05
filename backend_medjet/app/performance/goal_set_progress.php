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

$progress = $input['progress'] ?? null;
if ($progress === null) {
    Response::fail('progress is required', 400);
}
$progress = (int) $progress;
if ($progress < 0 || $progress > 100) {
    Response::fail('progress must be between 0 and 100', 422);
}

$goal = PerformanceGoalModel::findById($id, $tenantId);
if (!$goal) {
    Response::notFound('Goal');
}

$employee = EmployeeModel::findById((int) $goal['employee_id'], $tenantId);
if ($employee) {
    PermissionMiddleware::checkBranchAccess($auth, $employee['branch_id'] ?? null);
}

$status = $input['status'] ?? null;
if ($status !== null) {
    $status = Validator::enum($status, PerformanceGoalModel::STATUSES, 'status');
}

PerformanceGoalModel::setProgress($id, $tenantId, $progress, $status);

AuditLogModel::log($tenantId, $auth['admin_id'], 'performance_goal.set_progress', 'performance_goal', $id, ['progress' => $progress, 'status' => $status]);

Response::success(['message' => 'Goal progress updated']);
