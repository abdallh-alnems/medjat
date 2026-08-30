<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

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

if (!DocumentModel::delete($docId, $tenantId)) {
    Response::error('Failed to delete document', 500);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'document.delete', 'employee_document', $docId);

// Let the employee know their submission was removed so they can re-upload.
try {
    $docName = $doc['document_name'] ?? ($doc['original_name'] ?? 'المستند');
    $bodyAr = "تمت إزالة مستند \"{$docName}\". يمكنك رفعه من جديد.";
    $bodyEn = "Your document \"{$docName}\" was removed. You can upload it again.";
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'general', 'Document Removed', 'تمت إزالة مستند', ?, ?, ?, 'push,in_app', NOW())",
        [$tenantId, $doc['employee_id'], $bodyEn, $bodyAr,
         json_encode(['employee_document_id' => $docId, 'action' => 'remove'])]
    );
    NotificationService::sendToEmployee(
        (int) $doc['employee_id'],
        'تمت إزالة مستند',
        $bodyAr,
        ['employee_document_id' => (string) $docId, 'action' => 'remove', 'type' => 'document_removed']
    );
} catch (Exception $e) {
    error_log('Document delete notification error: ' . $e->getMessage());
}

Response::success(['document_id' => $docId]);
