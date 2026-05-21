<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$page = max(1, (int) ($_GET['page'] ?? 1));
$limit = min(50, max(1, (int) ($_GET['limit'] ?? 20)));
$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;
$search = $_GET['search'] ?? null;

if ($branchId) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

$result = EmployeeModel::getByTenant($tenantId, $page, $limit, $branchId, $search);

foreach ($result['items'] as &$emp) {
    $emp['category_ids'] = EmployeeCategoryModel::getEmployeeCategoryIds((int) $emp['id'], $tenantId);
}
unset($emp);

Response::success($result);
