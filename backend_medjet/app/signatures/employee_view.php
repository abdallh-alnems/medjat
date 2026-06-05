<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];

$requestId = (int) ($_GET['signature_request_id'] ?? 0);
Validator::required($requestId, 'signature_request_id');

$req = SignatureRequestModel::find($requestId, $tenantId);
if (!$req) {
    Response::notFound('Signature request');
}

$isParty = false;
foreach ($req['parties'] as $p) {
    if ($p['signer_type'] === 'employee' && (int) $p['signer_employee_id'] === $employeeId) {
        $isParty = true;
        break;
    }
}
if (!$isParty) {
    Response::forbidden('You are not a party in this signature request');
}

if (empty($req['source_pdf_path'])) {
    Response::fail('No document available for preview', 404);
}

$path = $req['source_pdf_path'];
if (!is_file($path)) {
    Response::error('Document file is unavailable', 500);
}

$downloadName = 'document_preview_' . $requestId . '.pdf';

header('Content-Type: application/pdf');
header('Content-Disposition: inline; filename="' . $downloadName . '"');
header('Content-Length: ' . filesize($path));
header('Cache-Control: private, max-age=0, must-revalidate');
readfile($path);
exit;
