<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

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

$deleted = DocumentModel::deleteRequired($id, $tenantId);
if (!$deleted) {
    Response::error('Failed to delete required document', 500);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'document_type.delete', 'required_document', $id);

Response::success(null);
