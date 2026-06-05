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

$review = PerformanceModel::findById($id, $tenantId);
if (!$review) {
    Response::notFound('Review');
}

$employee = EmployeeModel::findById((int) $review['employee_id'], $tenantId);
if ($employee) {
    PermissionMiddleware::checkBranchAccess($auth, $employee['branch_id'] ?? null);
}

$data = [];
$allowed = ['rating', 'strengths', 'areas_for_improvement', 'review', 'status', 'reviewer_type'];
foreach ($allowed as $key) {
    if (array_key_exists($key, $input)) {
        $data[$key] = $input[$key];
    }
}

if (isset($data['rating'])) {
    $data['rating'] = Validator::numeric($data['rating'], 'rating');
    if ($data['rating'] < 0 || $data['rating'] > 5) {
        Response::fail('rating must be between 0 and 5', 422);
    }
}
if (isset($data['reviewer_type'])) {
    $data['reviewer_type'] = Validator::enum($data['reviewer_type'], PerformanceModel::REVIEWER_TYPES, 'reviewer_type');
}
if (isset($data['status'])) {
    $data['status'] = Validator::enum($data['status'], PerformanceModel::STATUSES, 'status');
}

PerformanceModel::update($id, $tenantId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'performance_review.update', 'performance_review', $id);

Response::success(['message' => 'Review updated']);
