<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];

$month = $_GET['month'] ?? date('Y-m');
$records = AttendanceModel::getByEmployeeMonth($employee['id'], $month, $tenantId);

Response::success([
    'records' => $records,
    'month' => $month,
    'employee_id' => (int) $employee['id'],
]);
