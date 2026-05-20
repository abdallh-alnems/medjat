<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'documents_verify');

$input = $auth['input'];
$docId = (int) ($input['document_id'] ?? 0);
$reason = $input['reason'] ?? null;
Validator::required($docId, 'document_id');
Validator::required($reason, 'reason');

$doc = DocumentModel::getDocumentById($docId, $tenantId);
if (!$doc) {
    Response::notFound('Document');
}

DocumentModel::rejectDocument($docId, $tenantId, $reason);

AuditLogModel::log($tenantId, $auth['admin_id'], 'document.reject', 'employee_document', $docId, ['reason' => $reason]);

Response::success(['document_id' => $docId]);
