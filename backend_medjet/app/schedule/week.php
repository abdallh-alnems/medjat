<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_company_settings');

$weekStart = $_GET['week_start'] ?? '';
if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $weekStart)) {
    Response::fail('week_start (YYYY-MM-DD) required', 422);
}
$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;

$weekEnd = date('Y-m-d', strtotime($weekStart . ' +6 days'));
$days = [];
for ($i = 0; $i < 7; $i++) {
    $days[] = date('Y-m-d', strtotime($weekStart . " +{$i} days"));
}

Response::success([
    'week_start' => $weekStart,
    'week_end' => $weekEnd,
    'days' => $days,
    'employees' => EmployeeShiftScheduleModel::getRosterEmployees($tenantId, $branchId),
    'shifts' => ShiftModel::getByTenant($tenantId, $branchId),
    'cells' => EmployeeShiftScheduleModel::getCells($tenantId, $weekStart, $weekEnd, $branchId),
]);
