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
if ((int) $template['is_system'] === 1) {
    Response::fail('System templates cannot be deleted. You can deactivate it instead.', 422);
}

$deleted = DocumentTemplateModel::delete($id, $tenantId);
if (!$deleted) {
    Response::fail('Failed to delete template', 422);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'document_template.delete', 'document_template', $id);

Response::success(['message' => 'Template deleted']);
