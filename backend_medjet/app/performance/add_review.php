<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$rating = (float) ($input['rating'] ?? 0);
$review = $input['review'] ?? '';

Validator::required($employeeId, 'employee_id');

if ($rating < 1 || $rating > 5) {
    Response::fail('Rating must be between 1 and 5', 400);
}

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$id = PerformanceModel::addReview($employeeId, $tenantId, $rating, $review, $auth['admin_id']);

Response::success(['id' => $id, 'message' => 'Performance review added']);
