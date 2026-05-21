<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_documents');

$id = (int) ($_GET['id'] ?? 0);
Validator::required($id, 'id');

$request = DocumentRequestModel::find($id, $tenantId);
if (!$request) {
    Response::notFound('Request');
}
if ($request['status'] !== 'approved' || empty($request['pdf_path'])) {
    Response::fail('No document available for this request', 404);
}

$path = $request['pdf_path'];
if (!is_file($path)) {
    // Regenerate on the fly if the stored file is missing.
    try {
        $path = LetterPdfService::generateForRequest($request, $tenantId);
        DocumentRequestModel::setPdfPath($id, $tenantId, $path);
    } catch (Throwable $e) {
        error_log('Letter PDF regeneration failed: ' . $e->getMessage());
        Response::error('Document file is unavailable', 500);
    }
}

$downloadName = 'document_' . $id . '.pdf';

header('Content-Type: application/pdf');
header('Content-Disposition: inline; filename="' . $downloadName . '"');
header('Content-Length: ' . filesize($path));
header('Cache-Control: private, max-age=0, must-revalidate');
readfile($path);
exit;
