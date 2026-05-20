<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'documents_view_reports');

$branchId = isset($_GET['branch_id']) ? (int) $_GET['branch_id'] : null;

$documents = DocumentModel::getExpired($tenantId, $branchId);

Response::success(['documents' => $documents]);
