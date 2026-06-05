<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_schedule');
$input = $auth['input'];

Validator::required($input['shift_id'] ?? null, 'shift_id');
Validator::required($input['work_date'] ?? null, 'work_date');

$shiftId = (int) $input['shift_id'];
$workDate = $input['work_date'];
if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $workDate)) Response::fail('work_date must be YYYY-MM-DD', 422);

$shift = ShiftModel::findById($shiftId, $tenantId);
if (!$shift) Response::notFound('Shift');

$slots = isset($input['slots']) ? (int) $input['slots'] : 1;
if ($slots < 1) Response::fail('slots must be >= 1', 422);

$branchId = isset($input['branch_id']) ? (int) $input['branch_id'] : null;
if ($branchId !== null) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

$id = OpenShiftModel::create($tenantId, [
    'shift_id' => $shiftId,
    'work_date' => $workDate,
    'slots' => $slots,
    'branch_id' => $branchId,
    'notes' => $input['notes'] ?? null,
], (int) $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'schedule.open_shift_create', 'open_shift', $id, [
    'shift_id' => $shiftId, 'work_date' => $workDate, 'slots' => $slots,
]);

Response::success(['id' => $id]);
