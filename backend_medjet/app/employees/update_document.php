<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_documents');

$input = $auth['input'];
$docId = (int) ($input['document_id'] ?? 0);
Validator::required($docId, 'document_id');

$doc = DocumentModel::getDocumentById($docId, $tenantId);
if (!$doc) {
    Response::notFound('Document');
}

$fields = [];
if (array_key_exists('notes', $input)) {
    $fields['notes'] = $input['notes'];
}
if (array_key_exists('expires_at', $input)) {
    if ($input['expires_at'] !== null && $input['expires_at'] !== '') {
        Validator::date($input['expires_at'], 'expires_at');
    }
    $fields['expires_at'] = $input['expires_at'] ?: null;
}

if (!empty($fields)) {
    DocumentModel::updateDocument($docId, $tenantId, $fields);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'document.update', 'employee_document', $docId);

Response::success(['document_id' => $docId]);
