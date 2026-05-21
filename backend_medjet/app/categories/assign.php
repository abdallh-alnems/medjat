<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');

$categoryIds = is_array($input['category_ids'] ?? null)
    ? array_map('intval', $input['category_ids'])
    : [];

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

EmployeeCategoryModel::assignToEmployee($employeeId, $tenantId, $categoryIds);

AuditLogModel::log($tenantId, $auth['admin_id'], 'employee_category.assign', 'employee', $employeeId, ['category_ids' => $categoryIds]);

Response::success(['message' => 'Categories assigned']);
