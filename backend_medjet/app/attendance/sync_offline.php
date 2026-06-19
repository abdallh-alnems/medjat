<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];

$input = $auth['input'];
$records = $input['records'] ?? [];

if (empty($records) || !is_array($records)) {
    Response::fail('Records array is required', 400, 'records_required');
}

$employee = $auth['employee'];

$employeeId = $employee['id'];

$result = AttendanceModel::syncOffline($records, $employeeId, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'attendance.offline_sync', null, null, [
    'synced' => $result['synced'],
    'failed' => $result['failed'],
]);

Response::success($result);
