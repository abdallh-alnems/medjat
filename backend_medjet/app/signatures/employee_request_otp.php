<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];

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

if ($party['signer_type'] !== 'employee' || (int) $party['signer_employee_id'] !== $employeeId) {
    Response::forbidden('You are not the current signer');
}

SignatureService::issueOtp($tenantId, $requestId, $party);

Response::success(['message' => 'OTP sent']);
