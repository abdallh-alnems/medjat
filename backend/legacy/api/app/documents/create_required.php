<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'documents_manage_types');

$input = $auth['input'];
$name = $input['name'] ?? null;
Validator::required($name, 'name');

$fields = ['name' => $name];

if (isset($input['description'])) {
    $fields['description'] = $input['description'];
}
if (isset($input['expiry_days'])) {
    $fields['expiry_days'] = (int) $input['expiry_days'] ?: null;
}
if (isset($input['notification_days_before'])) {
    $fields['notification_days_before'] = (int) $input['notification_days_before'];
}
if (isset($input['category'])) {
    Validator::enum($input['category'], ['identity', 'contract', 'certificate', 'insurance', 'general'], 'category');
    $fields['category'] = $input['category'];
}
if (isset($input['sort_order'])) {
    $fields['sort_order'] = (int) $input['sort_order'];
}
if (isset($input['is_required'])) {
    $fields['is_required'] = (int) $input['is_required'] ? 1 : 0;
}

$scopeType = $input['scope_type'] ?? 'all';
Validator::enum($scopeType, ['all', 'branch', 'employees', 'category'], 'scope_type');
$fields['scope_type'] = $scopeType;

if ($scopeType === 'branch') {
    $branchId = (int) ($input['scope_branch_id'] ?? 0);
    Validator::required($branchId, 'scope_branch_id');
    $fields['scope_branch_id'] = $branchId;
} else {
    $fields['scope_branch_id'] = null;
}

$employeeIds = [];
if ($scopeType === 'employees') {
    $employeeIds = is_array($input['scope_employee_ids'] ?? null)
        ? $input['scope_employee_ids']
        : [];
    if (empty($employeeIds)) {
        Response::fail('scope_employee_ids is required when scope_type=employees', 400, 'scope_employee_ids_required_scope');
    }
}

$categoryIds = [];
if ($scopeType === 'category') {
    $categoryIds = is_array($input['scope_category_ids'] ?? null)
        ? $input['scope_category_ids']
        : [];
    if (empty($categoryIds)) {
        Response::fail('scope_category_ids is required when scope_type=category', 400, 'scope_category_ids_required_scope');
    }
}

$id = DocumentModel::addRequiredFull($tenantId, $fields);

if ($scopeType === 'employees') {
    DocumentModel::setEmployeeScope($id, $tenantId, $employeeIds);
}

if ($scopeType === 'category') {
    DocumentModel::setCategoryScope($id, $tenantId, $categoryIds);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'document_type.create', 'required_document', $id);

Response::success(['required_document_id' => $id], 201);
