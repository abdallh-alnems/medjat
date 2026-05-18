<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$employee = EmployeeModel::findByAdminId($auth['admin_id'], $tenantId);
if (!$employee) {
    Response::fail('Employee profile not found', 404);
}

AttendanceModel::checkOut($employee['id'], $tenantId);

Response::success([
    'message' => 'Check-out successful',
    'time' => date('H:i:s'),
]);
