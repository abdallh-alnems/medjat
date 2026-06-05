<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_documents');

$status = $_GET['status'] ?? null;
if ($status !== null && $status !== '' && !in_array($status, SignatureRequestModel::STATUSES, true)) {
    Response::fail('Invalid status filter', 400);
}
$entityType = $_GET['entity_type'] ?? null;
$page = max(1, (int) ($_GET['page'] ?? 1));

$result = SignatureRequestModel::listByTenant($tenantId, $status, $entityType, $page);

Response::success($result);
