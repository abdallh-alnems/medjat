<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'add_managers');

$statusFilter = $_GET['status'] ?? null;
$invitations = ManagerInvitationModel::getByTenant($tenantId, $statusFilter);

foreach ($invitations as &$inv) {
    unset($inv['token_hash']);
}

Response::success(['items' => $invitations]);
