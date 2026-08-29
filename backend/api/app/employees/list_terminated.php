<?php
/**
 * GET /app/employees/list_terminated.php?page=&limit=&search=
 *
 * Lists employees whose service has ended (status = 'terminated'), with their
 * branch and last end-of-service settlement summary, for the "re-hire" screen.
 * The regular list.php hides terminated employees, so this is a dedicated view.
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$page = max(1, (int) ($_GET['page'] ?? 1));
$limit = min(50, max(1, (int) ($_GET['limit'] ?? 20)));
$search = $_GET['search'] ?? null;

$result = EmployeeModel::getTerminatedByTenant($tenantId, $page, $limit, $search);
$result['total'] = EmployeeModel::terminatedCount($tenantId, $search);
$result['currency'] = TenantModel::findById($tenantId)['currency'] ?? 'EGP';

Response::success($result);
