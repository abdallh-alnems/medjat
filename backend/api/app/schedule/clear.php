<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$workDate = $input['work_date'] ?? '';

if (!$employeeId || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $workDate)) {
    Response::fail('employee_id and work_date (YYYY-MM-DD) required', 422, 'employee_id_work_date_yyyy');
}

EmployeeShiftScheduleModel::clearCell($tenantId, $employeeId, $workDate);

AuditLogModel::log($tenantId, $auth['admin_id'], 'schedule.clear', 'schedule', $employeeId, [
    'work_date' => $workDate,
]);

Response::success(['message' => 'Cleared']);
