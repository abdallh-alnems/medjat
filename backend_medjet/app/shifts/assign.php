<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$shiftId = (int) ($input['shift_id'] ?? 0);
$employeeIds = $input['employee_ids'] ?? [];

if (!$shiftId || !is_array($employeeIds) || empty($employeeIds)) {
    Response::fail('shift_id and employee_ids array required', 422, 'shift_id_employee_ids_array');
}

$shift = ShiftModel::findById($shiftId, $tenantId);
if (!$shift) Response::notFound('Shift');

$employeeIds = array_map('intval', $employeeIds);
$count = ShiftModel::assignEmployees($shiftId, $employeeIds, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'shift.assign', 'shift', $shiftId, ['count' => $count]);

Response::success(['assigned' => $count]);
