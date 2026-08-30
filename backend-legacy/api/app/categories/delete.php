<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
Validator::required($id, 'id');

$category = EmployeeCategoryModel::findById($id, $tenantId);
if (!$category) {
    Response::notFound('Category');
}

if (EmployeeCategoryModel::isUsedByDocuments($id, $tenantId)) {
    Response::fail('category_in_use_cannot_delete', 409, 'category_cannot_delete');
}

EmployeeCategoryModel::delete($id, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'employee_category.delete', 'employee_category', $id);

Response::success(['message' => 'Category deleted']);
