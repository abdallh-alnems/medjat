<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_approvals');

$input = $auth['input'];
$requestId = (int) ($input['request_id'] ?? 0);
Validator::required($requestId, 'request_id');

$req = ApprovalRequestModel::findById($requestId, $tenantId);
if (!$req) {
    Response::notFound('Approval request');
}
if ($req['status'] !== 'pending') {
    Response::fail('Request is not pending', 409);
}

ApprovalRequestModel::cancel($tenantId, $requestId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'approval.request.cancel', $req['entity_type'], (int) $req['entity_id'],
    ['request_id' => $requestId]);

Response::success(['message' => 'Approval request cancelled']);
