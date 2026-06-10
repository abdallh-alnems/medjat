<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_leaves');

$page = max(1, (int) ($_GET['page'] ?? 1));
$limit = min(500, max(1, (int) ($_GET['limit'] ?? 200)));
$status = $_GET['status'] ?? null;
$branchId = isset($_GET['branch_id']) && $_GET['branch_id'] !== '' ? (int) $_GET['branch_id'] : null;
$categoryId = isset($_GET['category_id']) && $_GET['category_id'] !== '' ? (int) $_GET['category_id'] : null;
$search = isset($_GET['q']) && trim((string) $_GET['q']) !== '' ? (string) $_GET['q'] : null;

$result = LeaveModel::getByTenant($tenantId, $page, $limit, $status, $branchId, $categoryId, $search);

Response::success($result);
