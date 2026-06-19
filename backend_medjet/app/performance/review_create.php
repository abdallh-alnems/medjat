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

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

PermissionMiddleware::checkBranchAccess($auth, $employee['branch_id'] ?? null);

$rating = $input['rating'] ?? null;
if ($rating !== null) {
    $rating = Validator::numeric($rating, 'rating');
    if ($rating < 0 || $rating > 5) {
        Response::fail('rating must be between 0 and 5', 422, 'rating_between_0_5');
    }
}

$reviewerType = Validator::enum($input['reviewer_type'] ?? 'manager', PerformanceModel::REVIEWER_TYPES, 'reviewer_type');

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
    'reviewer_type' => $reviewerType,
    'rating' => $rating,
    'strengths' => $input['strengths'] ?? null,
    'areas_for_improvement' => $input['areas_for_improvement'] ?? null,
    'review' => $input['review'] ?? null,
    'status' => $input['status'] ?? 'submitted',
];

if (isset($data['status'])) {
    $data['status'] = Validator::enum($data['status'], PerformanceModel::STATUSES, 'status');
}

$id = PerformanceModel::create($tenantId, $data, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'performance_review.create', 'performance_review', $id, ['employee_id' => $employeeId, 'rating' => $rating]);

Response::success(['id' => $id, 'message' => 'Review created'], 201);
