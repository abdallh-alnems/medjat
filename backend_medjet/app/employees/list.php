<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$page = max(1, (int) ($_GET['page'] ?? 1));
$limit = min(50, max(1, (int) ($_GET['limit'] ?? 20)));
$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;
$shiftId = ($_GET['shift_id'] ?? null) ? (int) $_GET['shift_id'] : null;
$categoryId = ($_GET['category_id'] ?? null) ? (int) $_GET['category_id'] : null;
$search = $_GET['search'] ?? null;
$status = $_GET['status'] ?? null;
$sort = $_GET['sort'] ?? 'name';
$dir = strtolower((string) ($_GET['dir'] ?? 'asc')) === 'desc' ? 'desc' : 'asc';
$expiringWithin = ($_GET['expiring_within'] ?? null) ? (int) $_GET['expiring_within'] : null;

if ($branchId) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

$result = EmployeeModel::getByTenant(
    $tenantId,
    $page,
    $limit,
    $branchId,
    $search,
    $status,
    $sort,
    $shiftId,
    $categoryId,
    $expiringWithin,
    $dir
);

foreach ($result['items'] as &$emp) {
    $emp['category_ids'] = EmployeeCategoryModel::getEmployeeCategoryIds((int) $emp['id'], $tenantId);
}
unset($emp);

// Status headcount for the stats header (branch-scoped, ignores other filters).
$result['stats'] = EmployeeModel::statusCounts($tenantId, $branchId);

Response::success($result);
