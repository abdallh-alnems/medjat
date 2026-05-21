<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$name = $input['name'] ?? null;
Validator::required($name, 'name');

$existing = EmployeeCategoryModel::findByName(trim($name), $tenantId);
if ($existing) {
    Response::fail('category_name_exists', 409);
}

$description = $input['description'] ?? null;
$color = $input['color'] ?? null;

$id = EmployeeCategoryModel::create($tenantId, trim($name), $description, $color);

AuditLogModel::log($tenantId, $auth['admin_id'], 'employee_category.create', 'employee_category', $id);

Response::success(['category_id' => $id], 201);
