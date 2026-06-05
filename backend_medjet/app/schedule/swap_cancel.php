<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];
$input = $auth['input'];

Validator::required($input['id'] ?? null, 'id');
$id = (int) $input['id'];

ShiftSwapModel::cancel($tenantId, $id, $employeeId);

AuditLogModel::log($tenantId, null, 'schedule.swap_cancel', 'shift_swap', $id);

Response::success(['cancelled' => true]);
