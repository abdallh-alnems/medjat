<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$requests = ApprovalRequestModel::inboxFor($tenantId, $auth['admin_id'], $auth['role']);

Response::success(['requests' => $requests]);
