<?php
/**
 * Overtime & lateness report.
 *
 * Aggregates the `overtime_minutes` / `late_minutes` written on each present
 * attendance row into per-employee totals for a period, plus a company-wide
 * summary. Passing `employee_id` additionally returns that employee's day-by-day
 * breakdown, which is what the drill-down in the app/web page reads.
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'view_reports');

$startDate = Validator::date($_GET['start_date'] ?? date('Y-m-01'), 'start_date');
$endDate = Validator::date($_GET['end_date'] ?? date('Y-m-d'), 'end_date');
$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;
$employeeId = ($_GET['employee_id'] ?? null) ? (int) $_GET['employee_id'] : null;
$sort = Validator::enum($_GET['sort'] ?? 'overtime', ['overtime', 'late', 'name'], 'sort');

if ($startDate > $endDate) {
    Response::fail('Start date must be on or before end date', 422, 'start_date_before_end_date');
}

if ($branchId) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

$payload = [
    'start_date' => $startDate,
    'end_date' => $endDate,
    'items' => AttendanceModel::getOvertimeLateReport($tenantId, $startDate, $endDate, $branchId, $sort),
    'summary' => AttendanceModel::getOvertimeLateSummary($tenantId, $startDate, $endDate, $branchId),
];

// Drill-down: the daily rows behind one employee's totals.
if ($employeeId) {
    $payload['days'] = AttendanceModel::getOvertimeLateDaily($tenantId, $employeeId, $startDate, $endDate);
}

Response::success($payload);
