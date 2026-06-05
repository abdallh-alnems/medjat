<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_documents');

$input = $auth['input'];
$requestId = (int) ($input['signature_request_id'] ?? 0);
Validator::required($requestId, 'signature_request_id');

$req = SignatureRequestModel::find($requestId, $tenantId);
if (!$req) {
    Response::notFound('Signature request');
}

SignatureService::void($tenantId, $requestId, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'signature.void', $req['entity_type'], (int) $req['entity_id'],
    ['signature_request_id' => $requestId]);

Response::success(['message' => 'Signature request voided']);
