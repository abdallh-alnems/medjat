<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];
$input = $auth['input'];

Validator::required($input['open_shift_id'] ?? null, 'open_shift_id');
$openShiftId = (int) $input['open_shift_id'];

$claimId = OpenShiftModel::claim($tenantId, $openShiftId, $employeeId);

AuditLogModel::log($tenantId, null, 'schedule.open_shift_claim', 'open_shift_claim', $claimId, [
    'open_shift_id' => $openShiftId,
]);

Response::success(['claim_id' => $claimId]);
