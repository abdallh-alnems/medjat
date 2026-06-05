<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_documents');

$input = $auth['input'];
$documentRequestId = (int) ($input['document_request_id'] ?? 0);
Validator::required($documentRequestId, 'document_request_id');

$parties = $input['parties'] ?? [];
if (!is_array($parties) || count($parties) < 1) {
    Response::fail('At least one signing party is required', 422);
}

$signingOrder = $input['signing_order'] ?? 'sequential';
Validator::enum($signingOrder, ['sequential', 'parallel'], 'signing_order');

$expiresAt = $input['expires_at'] ?? null;
if ($expiresAt !== null && $expiresAt !== '') {
    Validator::date($expiresAt, 'expires_at');
    $expiresAt = date('Y-m-d H:i:s', strtotime($expiresAt . ' 23:59:59'));
}

$requestId = SignatureService::open(
    $tenantId,
    $documentRequestId,
    $parties,
    $signingOrder,
    $expiresAt,
    $auth['admin_id']
);

AuditLogModel::log($tenantId, $auth['admin_id'], 'signature.open', 'document_request', $documentRequestId,
    ['signature_request_id' => $requestId]);

Response::success(['signature_request_id' => $requestId], 201);
