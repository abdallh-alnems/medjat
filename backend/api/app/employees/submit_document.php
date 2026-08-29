<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = (int) $auth['tenant_id'];
$employeeId = (int) $auth['employee']['id'];

// The file is sent as multipart/form-data, so document_type_id arrives in
// $_POST (not the JSON body that authenticateEmployee parses).
$documentTypeId = (int) ($_POST['document_type_id'] ?? $auth['input']['document_type_id'] ?? 0);
Validator::required($documentTypeId, 'document_type_id');

// The document type must exist, be active, and apply to this employee by scope.
$applicable = DocumentModel::getRequiredForEmployee($employeeId, $tenantId);
$isApplicable = false;
foreach ($applicable as $rd) {
    if ((int) $rd['id'] === $documentTypeId) {
        $isApplicable = true;
        break;
    }
}
if (!$isApplicable) {
    Response::fail('This document is not required for you', 403, 'document_not_required');
}

$uploadDir = __DIR__ . '/../../../uploads/documents/' . $tenantId . '/';
if (!is_dir($uploadDir)) {
    mkdir($uploadDir, 0755, true);
}

if (isset($_FILES['file']) && $_FILES['file']['error'] === UPLOAD_ERR_OK) {
    $file = $_FILES['file'];
    $ext = pathinfo($file['name'], PATHINFO_EXTENSION);
    $allowed = explode(',', getenv('UPLOAD_ALLOWED_TYPES') ?: 'jpg,jpeg,png,pdf');

    if (!in_array(strtolower($ext), $allowed)) {
        Response::fail('File type not allowed', 400, 'file_type_not_allowed');
    }

    $maxSize = (int) (getenv('UPLOAD_MAX_SIZE') ?: 5242880);
    if ($file['size'] > $maxSize) {
        Response::fail('File size exceeds limit', 400, 'file_too_large');
    }

    $fileName = uniqid() . '_' . time() . '.' . $ext;
    $filePath = $uploadDir . $fileName;

    if (!move_uploaded_file($file['tmp_name'], $filePath)) {
        Response::error('Failed to save file', 500);
    }

    // Employee self-submission: status 'uploaded' with verified_at left NULL =
    // "awaiting admin review". The admin verifies it (sets verified_at) or
    // rejects it. ('pending' is intentionally NOT used — it is not a valid
    // value of the status ENUM and would be silently stored as '').
    $docId = DocumentModel::upload(
        $employeeId,
        $tenantId,
        $documentTypeId,
        $filePath,
        $file['name'],
        null,
        $file['size'],
        $file['type'],
        'uploaded'
    );

    // Tell the managers a document is waiting for their review.
    $empName = trim((string) ($auth['employee']['name'] ?? '')) ?: 'موظف';
    $docName = 'مستند';
    foreach ($applicable as $rd) {
        if ((int) $rd['id'] === $documentTypeId) {
            $docName = (string) $rd['name'];
            break;
        }
    }
    ManagerAlert::notify(
        $tenantId,
        'approval',
        'مستند بانتظار المراجعة',
        'Document awaiting review',
        "{$empName} أرسل مستند \"{$docName}\" للمراجعة.",
        "{$empName} submitted the document \"{$docName}\" for review.",
        $employeeId,
        // The management app opens the submissions screen for one *document
        // type*, so it needs required_document_id — the uploaded row id alone
        // is not enough to open that screen.
        [
            'action' => 'document_submitted',
            'employee_document_id' => (string) $docId,
            'required_document_id' => (string) $documentTypeId,
            'document_name' => $docName,
        ]
    );

    Response::success(['document_id' => $docId, 'status' => 'uploaded']);
} else {
    Response::fail('No file uploaded', 400, 'no_file');
}
