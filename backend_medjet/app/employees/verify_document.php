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

// Notify the employee that their document was approved.
try {
    $docName = $doc['document_name'] ?? ($doc['original_name'] ?? 'المستند');
    $bodyAr = "تمت الموافقة على مستند \"{$docName}\".";
    $bodyEn = "Your document \"{$docName}\" has been approved.";
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'document', 'Document Approved', 'تم قبول مستندك', ?, ?, ?, 'push,in_app', NOW())",
        [$tenantId, $doc['employee_id'], $bodyEn, $bodyAr,
         json_encode(['employee_document_id' => $docId, 'action' => 'approve'])]
    );
    NotificationService::sendToEmployee(
        (int) $doc['employee_id'],
        'تم قبول مستندك',
        $bodyAr,
        ['employee_document_id' => (string) $docId, 'action' => 'approve', 'type' => 'document_approved']
    );
} catch (Exception $e) {
    error_log('Document verify notification error: ' . $e->getMessage());
}

Response::success(['document_id' => $docId]);
