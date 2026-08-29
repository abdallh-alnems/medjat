<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_leaves');

$branchId   = isset($_GET['branch_id']) ? (int) $_GET['branch_id'] : null;
$categoryId = isset($_GET['category_id']) ? (int) $_GET['category_id'] : null;
$search     = isset($_GET['search']) ? trim((string) $_GET['search']) : null;
$status     = $_GET['status'] ?? null;
$from       = $_GET['from'] ?? null;
$to         = $_GET['to'] ?? null;

// Sweep out any pending request whose window already passed before listing,
// so the manager never sees (or can approve) a stale, expired permission.
BreakRequestModel::expirePastPending($tenantId);

$rows = BreakRequestModel::listForManager(
    $tenantId, $branchId, $status, $from, $to, $categoryId, $search
);
Response::success(['breaks' => $rows]);
