<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_leaves');

$branchId = isset($_GET['branch_id']) ? (int) $_GET['branch_id'] : null;
$status   = $_GET['status'] ?? null;
$from     = $_GET['from'] ?? null;
$to       = $_GET['to'] ?? null;

$rows = BreakRequestModel::listForManager($tenantId, $branchId, $status, $from, $to);
Response::success(['breaks' => $rows]);
