<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$employeeIds = $input['employee_ids'] ?? [];
$dates = $input['dates'] ?? [];
// shift_id omitted or null => rest / off day
$shiftId = array_key_exists('shift_id', $input) && $input['shift_id'] !== null
    ? (int) $input['shift_id']
    : null;

if (!is_array($employeeIds) || empty($employeeIds) || !is_array($dates) || empty($dates)) {
    Response::fail('employee_ids and dates arrays are required', 422, 'employee_ids_dates_arrays_required');
}
foreach ($dates as $d) {
    if (!is_string($d) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $d)) {
        Response::fail('dates must be YYYY-MM-DD strings', 422, 'dates_yyyy_mm_dd_strings');
    }
}

if ($shiftId !== null) {
    $shift = ShiftModel::findById($shiftId, $tenantId);
    if (!$shift) Response::notFound('Shift');
}

$count = EmployeeShiftScheduleModel::bulkAssign(
    $tenantId,
    $employeeIds,
    $dates,
    $shiftId,
    (int) $auth['admin_id']
);

AuditLogModel::log($tenantId, $auth['admin_id'], 'schedule.assign', 'schedule', null, [
    'cells' => $count,
    'shift_id' => $shiftId,
]);

Response::success(['updated' => $count]);
