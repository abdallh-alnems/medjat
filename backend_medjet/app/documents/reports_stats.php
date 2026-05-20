<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'documents_view_reports');

$stats = DocumentModel::getStatsByTenant($tenantId);

Response::success(['stats' => $stats]);
