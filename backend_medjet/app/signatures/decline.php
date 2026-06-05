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
if ($req['status'] !== 'pending') {
    Response::fail('Signature request already finalized', 409);
}

$party = SignaturePartyModel::currentParty($tenantId, $requestId, (int) $req['current_party']);
if (!$party || $party['status'] !== 'pending') {
    Response::fail('No pending step', 409);
}

$isCurrentSigner = $party['signer_type'] === 'admin'
    && ((int) $party['signer_admin_id'] === (int) $auth['admin_id'] || $auth['role'] === 'general_manager');
if (!$isCurrentSigner) {
    Response::forbidden('You are not the current signer');
}

$reason = $input['reason'] ?? null;
SignatureService::decline($tenantId, $requestId, $party, $reason);

AuditLogModel::log($tenantId, $auth['admin_id'], 'signature.decline', $req['entity_type'], (int) $req['entity_id'],
    ['signature_request_id' => $requestId, 'party_order' => $party['party_order']]);

Response::success(['message' => 'Signature request declined']);
