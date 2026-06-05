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

PerformanceModel::delete($id, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'performance_review.delete', 'performance_review', $id);

Response::success(['message' => 'Review deleted']);
