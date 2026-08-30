<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateEmployee(db());
$tenantId = (int) $auth['tenant_id'];
$employeeId = (int) $auth['employee']['id'];

$id = (int) ($_GET['id'] ?? 0);
Validator::required($id, 'id');

$doc = DocumentModel::getDocumentById($id, $tenantId);
// Employees may only view their own document files.
if (!$doc || (int) $doc['employee_id'] !== $employeeId || empty($doc['file_path'])) {
    Response::notFound('Document');
}

$filePath = $doc['file_path'];
if (!is_file($filePath)) {
    Response::notFound('File');
}

// Infer a content type: prefer the stored mime, fall back to the extension.
$mime = $doc['mime_type'] ?? '';
if ($mime === '' || $mime === null) {
    $ext = strtolower(pathinfo($filePath, PATHINFO_EXTENSION));
    $map = [
        'pdf' => 'application/pdf',
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'png' => 'image/png',
    ];
    $mime = $map[$ext] ?? 'application/octet-stream';
}

$downloadName = $doc['original_name'] ?: basename($filePath);

header('Content-Type: ' . $mime);
header('Content-Length: ' . filesize($filePath));
header('Content-Disposition: inline; filename="' . addslashes($downloadName) . '"');
header('X-Content-Type-Options: nosniff');
readfile($filePath);
exit;
