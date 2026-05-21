<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$input = $auth['input'];
$records = $input['records'] ?? [];

if (empty($records) || !is_array($records)) {
    Response::fail('Records array is required', 400);
}

$employee = EmployeeModel::findByAdminId($auth['admin_id'], $tenantId);
if (!$employee) {
    Response::fail('Employee profile not found', 404);
}

$employeeId = $employee['id'];

$result = AttendanceModel::syncOffline($records, $employeeId, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'attendance.offline_sync', null, null, [
    'synced' => $result['synced'],
    'failed' => $result['failed'],
]);

Response::success($result);
