<?php
require_once __DIR__ . '/../../config/bootstrap.php';

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

$fields = [];
if (array_key_exists('name', $input)) {
    Validator::required($input['name'], 'name');
    $duplicate = EmployeeCategoryModel::findByName(trim($input['name']), $tenantId, $id);
    if ($duplicate) {
        Response::fail('category_name_exists', 409);
    }
    $fields['name'] = trim($input['name']);
}
if (array_key_exists('description', $input)) {
    $fields['description'] = $input['description'];
}
if (array_key_exists('color', $input)) {
    $fields['color'] = $input['color'];
}
if (array_key_exists('is_active', $input)) {
    $fields['is_active'] = (int) $input['is_active'] ? 1 : 0;
}

if (!empty($fields)) {
    EmployeeCategoryModel::update($id, $tenantId, $fields);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'employee_category.update', 'employee_category', $id, $fields);

Response::success(['category_id' => $id]);
