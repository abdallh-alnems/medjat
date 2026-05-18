<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$employee = EmployeeModel::findByAdminId($auth['admin_id'], $tenantId);
if (!$employee) {
    Response::fail('Employee profile not found', 404);
}

$month = $_GET['month'] ?? date('Y-m');
$records = AttendanceModel::getByEmployeeMonth($employee['id'], $month, $tenantId);

Response::success([
    'records' => $records,
    'month' => $month,
    'employee_id' => (int) $employee['id'],
]);
