<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_schedule');

$startDate = $_GET['start_date'] ?? null;
$endDate = $_GET['end_date'] ?? null;
$branchId = isset($_GET['branch_id']) ? (int) $_GET['branch_id'] : null;

if (!$startDate || !$endDate) Response::fail('start_date and end_date are required', 400);
Validator::date($startDate, 'start_date');
Validator::date($endDate, 'end_date');

if ($branchId !== null) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

$data = EmployeeAvailabilityModel::forRosterWindow($tenantId, $startDate, $endDate, $branchId);

Response::success($data);
