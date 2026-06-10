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

// Notify the employee that their document was rejected, with the reason.
try {
    $docName = $doc['document_name'] ?? ($doc['original_name'] ?? 'المستند');
    $bodyAr = "تم رفض مستند \"{$docName}\". السبب: {$reason}";
    $bodyEn = "Your document \"{$docName}\" was rejected. Reason: {$reason}";
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'document', 'Document Rejected', 'تم رفض مستندك', ?, ?, ?, 'push,in_app', NOW())",
        [$tenantId, $doc['employee_id'], $bodyEn, $bodyAr,
         json_encode(['employee_document_id' => $docId, 'action' => 'reject', 'reason' => $reason])]
    );
    NotificationService::sendToEmployee(
        (int) $doc['employee_id'],
        'تم رفض مستندك',
        $bodyAr,
        ['employee_document_id' => (string) $docId, 'action' => 'reject', 'type' => 'document_rejected']
    );
} catch (Exception $e) {
    error_log('Document reject notification error: ' . $e->getMessage());
}

Response::success(['document_id' => $docId]);
