<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$fromStart = $input['from_week_start'] ?? '';
$toStart = $input['to_week_start'] ?? '';
$branchId = ($input['branch_id'] ?? null) ? (int) $input['branch_id'] : null;

if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $fromStart) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $toStart)) {
    Response::fail('from_week_start and to_week_start (YYYY-MM-DD) required', 422, 'from_week_start_week_start');
}

$fromEnd = date('Y-m-d', strtotime($fromStart . ' +6 days'));
$count = EmployeeShiftScheduleModel::copyWeek($tenantId, $fromStart, $fromEnd, $toStart, $branchId, (int) $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'schedule.copy_week', 'schedule', null, [
    'from' => $fromStart,
    'to' => $toStart,
    'cells' => $count,
]);

Response::success(['copied' => $count]);
