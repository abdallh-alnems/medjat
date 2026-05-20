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

DocumentModel::toggleRequiredActive($id, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'document_type.toggle_active', 'required_document', $id);

Response::success(['is_active' => !(bool) $existing['is_active']]);
