<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$weekStart = $input['week_start'] ?? '';
$branchId = ($input['branch_id'] ?? null) ? (int) $input['branch_id'] : null;

if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $weekStart)) {
    Response::fail('week_start (YYYY-MM-DD) required', 422, 'week_start_yyyy_mm_dd');
}

$weekEnd = date('Y-m-d', strtotime($weekStart . ' +6 days'));
$count = EmployeeShiftScheduleModel::publishWeek($tenantId, $weekStart, $weekEnd, $branchId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'schedule.publish', 'schedule', null, [
    'week_start' => $weekStart,
    'cells' => $count,
]);

Response::success(['published' => $count]);
