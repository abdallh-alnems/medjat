<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_company_settings');

$id = (int) ($_GET['id'] ?? $auth['input']['id'] ?? 0);
if (!$id) Response::fail('Shift ID required', 422);

$shift = ShiftModel::findById($id, $tenantId);
if (!$shift) Response::notFound('Shift');

$transferToShiftId = (int) ($auth['input']['transfer_to_shift_id'] ?? 0);
$affected = 0;
$scheduleMoved = 0;
$action = 'kept_times';

if ($transferToShiftId > 0) {
    if ($transferToShiftId === $id) {
        Response::fail('Cannot transfer employees to the shift being deleted', 422);
    }
    $target = ShiftModel::findById($transferToShiftId, $tenantId);
    if (!$target) Response::fail('Target shift not found', 422);

    // Move members onto the chosen shift before deleting, and repoint their
    // upcoming weekly-roster cells so scheduled days keep a valid shift too.
    $affected = ShiftModel::transferEmployees($id, $transferToShiftId, $tenantId);
    $scheduleMoved = EmployeeShiftScheduleModel::transferShift($id, $transferToShiftId, $tenantId);
    $action = 'transferred';
} else {
    // No target: preserve each member's schedule by copying this shift's
    // times onto their personal work hours, then let the FK null out shift_id.
    // Roster cells on this shift CASCADE away and fall back to those same times.
    $affected = ShiftModel::applyTimesToEmployees(
        $id,
        $shift['start_time'],
        $shift['end_time'],
        $tenantId
    );
}

ShiftModel::delete($id, $tenantId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'shift.delete', 'shift', $id, [
    'action' => $action,
    'affected' => $affected,
    'schedule_moved' => $scheduleMoved,
    'transfer_to_shift_id' => $transferToShiftId ?: null,
]);

Response::success([
    'message' => 'Deleted',
    'action' => $action,
    'affected' => $affected,
    'schedule_moved' => $scheduleMoved,
]);
