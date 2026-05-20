<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'documents_view_reports');

$daysAhead = (int) ($_GET['days_ahead'] ?? 30);
$branchId = isset($_GET['branch_id']) ? (int) $_GET['branch_id'] : null;

$documents = DocumentModel::getExpiringSoon($tenantId, $daysAhead, $branchId);

Response::success(['documents' => $documents]);
