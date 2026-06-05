<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];
$input = $auth['input'];

Validator::required($input['id'] ?? null, 'id');
Validator::required($input['response'] ?? null, 'response');
Validator::enum($input['response'], ['accept', 'reject'], 'response');

$id = (int) $input['id'];
$accept = $input['response'] === 'accept';

ShiftSwapModel::respondTarget($tenantId, $id, $employeeId, $accept);

AuditLogModel::log($tenantId, null, 'schedule.swap_respond', 'shift_swap', $id, [
    'response' => $input['response'],
]);

Response::success(['updated' => true]);
