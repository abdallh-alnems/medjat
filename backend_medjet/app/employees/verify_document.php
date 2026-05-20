<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'documents_verify');

$input = $auth['input'];
$docId = (int) ($input['document_id'] ?? 0);
Validator::required($docId, 'document_id');

$doc = DocumentModel::getDocumentById($docId, $tenantId);
if (!$doc) {
    Response::notFound('Document');
}

DocumentModel::verifyDocument($docId, $tenantId, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'document.verify', 'employee_document', $docId);

Response::success(['document_id' => $docId]);
