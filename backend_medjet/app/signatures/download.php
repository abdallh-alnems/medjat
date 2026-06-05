<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_documents');

$id = (int) ($_GET['id'] ?? 0);
Validator::required($id, 'id');

$req = SignatureRequestModel::find($id, $tenantId);
if (!$req) {
    Response::notFound('Signature request');
}
if ($req['status'] !== 'completed' || empty($req['signed_pdf_path'])) {
    Response::fail('No signed document available', 404);
}

$path = $req['signed_pdf_path'];
if (!is_file($path)) {
    Response::error('Signed document file is unavailable', 500);
}

$downloadName = 'signed_' . $id . '.pdf';

header('Content-Type: application/pdf');
header('Content-Disposition: inline; filename="' . $downloadName . '"');
header('Content-Length: ' . filesize($path));
header('Cache-Control: private, max-age=0, must-revalidate');
readfile($path);
exit;
