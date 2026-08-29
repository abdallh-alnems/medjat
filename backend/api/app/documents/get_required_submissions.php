<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_documents');

$requiredDocumentId = (int) ($_GET['required_document_id'] ?? 0);
Validator::required($requiredDocumentId, 'required_document_id');

$required = DocumentModel::getRequiredById($requiredDocumentId, $tenantId);
if (!$required) {
    Response::notFound('Required document');
}

$rows = DocumentModel::getSubmissionsForRequired($requiredDocumentId, $tenantId);

$submissions = [];
foreach ($rows as $r) {
    $document = null;
    if (!empty($r['document_id'])) {
        $document = [
            'id' => (int) $r['document_id'],
            'employee_id' => (int) $r['employee_id'],
            'required_document_id' => $requiredDocumentId,
            'document_name' => $r['document_name'],
            'status' => $r['status'],
            'original_name' => $r['original_name'],
            'file_path' => $r['file_path'],
            'mime_type' => $r['mime_type'],
            'verified_at' => $r['verified_at'],
            'rejected_reason' => $r['rejected_reason'],
            'expires_at' => $r['expires_at'],
            'created_at' => $r['uploaded_at'],
        ];
    }
    $submissions[] = [
        'employee_id' => (int) $r['employee_id'],
        'employee_name' => $r['employee_name'],
        'branch_name' => $r['branch_name'],
        'document' => $document,
    ];
}

Response::success([
    'required_document' => [
        'id' => (int) $required['id'],
        'name' => $required['name'],
    ],
    'submissions' => $submissions,
]);
