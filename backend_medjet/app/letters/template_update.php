<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_documents');

$input = $auth['input'];
$id = (int) ($input['template_id'] ?? $_GET['id'] ?? 0);
Validator::required($id, 'template_id');

$template = DocumentTemplateModel::find($id, $tenantId);
if (!$template) {
    Response::notFound('Template');
}

$data = [];
foreach (['name_ar', 'name_en', 'body_ar', 'body_en'] as $field) {
    if (isset($input[$field])) {
        $data[$field] = trim((string) $input[$field]);
    }
}
if (isset($input['is_active'])) {
    $data['is_active'] = (int) (bool) $input['is_active'];
}
if (isset($input['sort_order'])) {
    $data['sort_order'] = (int) $input['sort_order'];
}

if (isset($data['name_ar'])) {
    Validator::required($data['name_ar'], 'name_ar');
}
if (isset($data['body_ar'])) {
    Validator::required($data['body_ar'], 'body_ar');
}

DocumentTemplateModel::update($id, $tenantId, $data);

AuditLogModel::log($tenantId, $auth['admin_id'], 'document_template.update', 'document_template', $id);

Response::success(['message' => 'Template updated']);
