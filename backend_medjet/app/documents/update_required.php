<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'documents_manage_types');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
Validator::required($id, 'id');

$existing = DocumentModel::getRequiredById($id, $tenantId);
if (!$existing) {
    Response::notFound('Required document');
}

$fields = [];
if (array_key_exists('name', $input)) {
    Validator::required($input['name'], 'name');
    $fields['name'] = $input['name'];
}
if (array_key_exists('description', $input)) {
    $fields['description'] = $input['description'];
}
if (array_key_exists('expiry_days', $input)) {
    $fields['expiry_days'] = (int) $input['expiry_days'] ?: null;
}
if (array_key_exists('notification_days_before', $input)) {
    $fields['notification_days_before'] = (int) $input['notification_days_before'];
}
if (array_key_exists('category', $input)) {
    Validator::enum($input['category'], ['identity', 'contract', 'certificate', 'insurance', 'general'], 'category');
    $fields['category'] = $input['category'];
}
if (array_key_exists('sort_order', $input)) {
    $fields['sort_order'] = (int) $input['sort_order'];
}
if (array_key_exists('is_required', $input)) {
    $fields['is_required'] = (int) $input['is_required'] ? 1 : 0;
}

$scopeType = $input['scope_type'] ?? null;
if ($scopeType !== null) {
    Validator::enum($scopeType, ['all', 'branch', 'employees', 'category'], 'scope_type');
    $fields['scope_type'] = $scopeType;

    if ($scopeType === 'branch') {
        $branchId = (int) ($input['scope_branch_id'] ?? 0);
        Validator::required($branchId, 'scope_branch_id');
        $fields['scope_branch_id'] = $branchId;
    } else {
        $fields['scope_branch_id'] = null;
    }
}

DocumentModel::updateRequired($id, $tenantId, $fields);

if ($scopeType === 'employees' || ($scopeType === null && array_key_exists('scope_employee_ids', $input))) {
    $employeeIds = is_array($input['scope_employee_ids'] ?? null)
        ? $input['scope_employee_ids']
        : [];
    DocumentModel::setEmployeeScope($id, $tenantId, $employeeIds);
} elseif ($scopeType !== null && $scopeType !== 'employees') {
    DocumentModel::setEmployeeScope($id, $tenantId, []);
}

if ($scopeType === 'category' || ($scopeType === null && array_key_exists('scope_category_ids', $input))) {
    $categoryIds = is_array($input['scope_category_ids'] ?? null)
        ? $input['scope_category_ids']
        : [];
    DocumentModel::setCategoryScope($id, $tenantId, $categoryIds);
} elseif ($scopeType !== null && $scopeType !== 'category') {
    DocumentModel::setCategoryScope($id, $tenantId, []);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'document_type.update', 'required_document', $id);

Response::success(['required_document_id' => $id]);
