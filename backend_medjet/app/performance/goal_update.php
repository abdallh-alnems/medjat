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

$data = [];
$allowed = ['title', 'description', 'metric', 'target_value', 'current_value', 'weight', 'due_date', 'cycle_id', 'status'];
foreach ($allowed as $key) {
    if (array_key_exists($key, $input)) {
        $data[$key] = $input[$key];
    }
}

if (isset($data['status'])) {
    $data['status'] = Validator::enum($data['status'], PerformanceGoalModel::STATUSES, 'status');
}
if (isset($data['due_date']) && $data['due_date'] !== null) {
    Validator::date($data['due_date'], 'due_date');
}
if (isset($data['cycle_id']) && $data['cycle_id'] !== null) {
    $cycle = PerformanceCycleModel::findById((int) $data['cycle_id'], $tenantId);
    if (!$cycle) {
        Response::notFound('Cycle');
    }
}

PerformanceGoalModel::update($id, $tenantId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'performance_goal.update', 'performance_goal', $id);

Response::success(['message' => 'Goal updated']);
