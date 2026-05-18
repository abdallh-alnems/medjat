<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_documents');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$documentTypeId = (int) ($input['document_type_id'] ?? 0);

Validator::required($employeeId, 'employee_id');
Validator::required($documentTypeId, 'document_type_id');

$uploadDir = __DIR__ . '/../../uploads/documents/' . $tenantId . '/';
if (!is_dir($uploadDir)) {
    mkdir($uploadDir, 0755, true);
}

if (isset($_FILES['file']) && $_FILES['file']['error'] === UPLOAD_ERR_OK) {
    $file = $_FILES['file'];
    $ext = pathinfo($file['name'], PATHINFO_EXTENSION);
    $allowed = explode(',', getenv('UPLOAD_ALLOWED_TYPES') ?: 'jpg,jpeg,png,pdf');

    if (!in_array(strtolower($ext), $allowed)) {
        Response::fail('File type not allowed', 400);
    }

    $fileName = uniqid() . '_' . time() . '.' . $ext;
    $filePath = $uploadDir . $fileName;

    if (!move_uploaded_file($file['tmp_name'], $filePath)) {
        Response::error('Failed to save file', 500);
    }

    $docId = DocumentModel::upload($employeeId, $tenantId, $documentTypeId, $filePath, $file['name'], $auth['admin_id']);

    AuditLogModel::log($tenantId, $auth['admin_id'], 'document.upload', 'employee', $employeeId);

    Response::success(['document_id' => $docId]);
} else {
    Response::fail('No file uploaded', 400);
}
