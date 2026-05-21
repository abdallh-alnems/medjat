<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_company_settings');

// Which branding asset: logo | stamp | signature
$type = $_POST['type'] ?? ($auth['input']['type'] ?? '');
$columnMap = [
    'logo' => 'logo_url',
    'stamp' => 'stamp_url',
    'signature' => 'signature_url',
];
if (!isset($columnMap[$type])) {
    Response::fail('Invalid branding type. Use logo, stamp or signature.', 422);
}
$column = $columnMap[$type];

if (!isset($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) {
    Response::fail('No file uploaded', 400);
}

$file = $_FILES['file'];
$ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
$allowed = ['jpg', 'jpeg', 'png'];
if (!in_array($ext, $allowed, true)) {
    Response::fail('Only PNG/JPG images are allowed', 422);
}
$maxSize = (int) (getenv('UPLOAD_MAX_SIZE') ?: 5242880);
if ($file['size'] > $maxSize) {
    Response::fail('File size exceeds limit', 422);
}

$uploadDir = __DIR__ . '/../../uploads/branding/' . $tenantId . '/';
if (!is_dir($uploadDir) && !mkdir($uploadDir, 0755, true) && !is_dir($uploadDir)) {
    Response::error('Failed to create upload directory', 500);
}

$fileName = $type . '_' . uniqid() . '_' . time() . '.' . $ext;
$filePath = $uploadDir . $fileName;

if (!move_uploaded_file($file['tmp_name'], $filePath)) {
    Response::error('Failed to save file', 500);
}

// Remove the previous asset of this type to avoid orphan files.
$tenant = TenantModel::findById($tenantId);
$previous = $tenant[$column] ?? null;
if (!empty($previous) && is_file($previous) && $previous !== $filePath) {
    @unlink($previous);
}

TenantModel::update($tenantId, [$column => $filePath]);

AuditLogModel::log($tenantId, $auth['admin_id'], 'tenant.upload_branding', 'tenant', $tenantId);

Response::success(['message' => 'Uploaded', 'type' => $type]);
