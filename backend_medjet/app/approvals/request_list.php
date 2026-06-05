<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_approvals');

$status = $_GET['status'] ?? null;
$entityType = $_GET['entity_type'] ?? null;

if ($status !== null && !in_array($status, ApprovalRequestModel::STATUSES, true)) {
    Response::fail('Invalid status filter', 422);
}
if ($entityType !== null && !in_array($entityType, ApprovalChainModel::REQUEST_TYPES, true)) {
    Response::fail('Invalid entity_type filter', 422);
}

$requests = ApprovalRequestModel::listByTenant($tenantId, $status, $entityType);

Response::success(['requests' => $requests]);
