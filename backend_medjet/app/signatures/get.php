<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_documents');

$id = (int) ($_GET['id'] ?? 0);
Validator::required($id, 'id');

$req = SignatureRequestModel::find($id, $tenantId);
if (!$req) {
    Response::notFound('Signature request');
}

if (isset($req['parties'])) {
    foreach ($req['parties'] as &$party) {
        unset($party['otp_hash']);
    }
    unset($party);
}

Response::success($req);
