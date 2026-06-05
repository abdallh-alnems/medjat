<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_performance');
$input = $auth['input'];

$employeeId = (int) ($input['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');
$title = trim((string) ($input['title'] ?? ''));
Validator::required($title, 'title');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

PermissionMiddleware::checkBranchAccess($auth, $employee['branch_id'] ?? null);

$cycleId = isset($input['cycle_id']) ? (int) $input['cycle_id'] : null;
if ($cycleId !== null) {
    $cycle = PerformanceCycleModel::findById($cycleId, $tenantId);
    if (!$cycle) {
        Response::notFound('Cycle');
    }
}

$data = [
    'employee_id' => $employeeId,
    'cycle_id' => $cycleId,
    'title' => $title,
    'description' => $input['description'] ?? null,
    'metric' => $input['metric'] ?? null,
    'target_value' => $input['target_value'] ?? null,
    'current_value' => $input['current_value'] ?? 0.00,
    'weight' => (int) ($input['weight'] ?? 0),
    'progress' => (int) ($input['progress'] ?? 0),
    'status' => $input['status'] ?? 'not_started',
    'due_date' => $input['due_date'] ?? null,
];

if (isset($data['status'])) {
    $data['status'] = Validator::enum($data['status'], PerformanceGoalModel::STATUSES, 'status');
}
if (isset($data['due_date']) && $data['due_date'] !== null) {
    Validator::date($data['due_date'], 'due_date');
}

$id = PerformanceGoalModel::create($tenantId, $data, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'performance_goal.create', 'performance_goal', $id, ['employee_id' => $employeeId, 'title' => $title]);

Response::success(['id' => $id, 'message' => 'Goal created'], 201);
