<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];
$input = $auth['input'];

Validator::required($input['target_employee_id'] ?? null, 'target_employee_id');
Validator::required($input['requester_date'] ?? null, 'requester_date');
Validator::required($input['target_date'] ?? null, 'target_date');

if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $input['requester_date'])) {
    Response::fail('requester_date must be YYYY-MM-DD', 422);
}
if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $input['target_date'])) {
    Response::fail('target_date must be YYYY-MM-DD', 422);
}

$targetEmployeeId = (int) $input['target_employee_id'];
$targetEmp = Database::fetchOne(
    "SELECT id FROM employees WHERE id = ? AND tenant_id = ?",
    [$targetEmployeeId, $tenantId]
);
if (!$targetEmp) Response::notFound('Target employee');

$id = ShiftSwapModel::create($tenantId, [
    'requester_employee_id' => $employeeId,
    'target_employee_id' => $targetEmployeeId,
    'requester_date' => $input['requester_date'],
    'target_date' => $input['target_date'],
    'note' => $input['note'] ?? null,
]);

AuditLogModel::log($tenantId, null, 'schedule.swap_request', 'shift_swap', $id, [
    'target_employee_id' => $targetEmployeeId,
]);

Response::success(['id' => $id]);
