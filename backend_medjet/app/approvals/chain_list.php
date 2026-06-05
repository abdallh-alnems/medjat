<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_approvals');

$requestType = $_GET['request_type'] ?? null;

$chains = ApprovalChainModel::listByTenant($tenantId, $requestType);

Response::success(['chains' => $chains]);
