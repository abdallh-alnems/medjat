<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_documents');

$page = max(1, (int) ($_GET['page'] ?? 1));
$status = $_GET['status'] ?? null;
if ($status !== null && !in_array($status, ['pending', 'approved', 'rejected'], true)) {
    $status = null;
}

$result = DocumentRequestModel::getByTenant($tenantId, $status, $page);

Response::success($result);
