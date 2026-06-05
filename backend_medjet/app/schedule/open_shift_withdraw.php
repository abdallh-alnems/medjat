<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];
$input = $auth['input'];

Validator::required($input['claim_id'] ?? null, 'claim_id');
$claimId = (int) $input['claim_id'];

$withdrawn = OpenShiftModel::withdrawClaim($tenantId, $claimId, $employeeId);
if (!$withdrawn) Response::notFound('Claim');

AuditLogModel::log($tenantId, null, 'schedule.open_shift_withdraw', 'open_shift_claim', $claimId);

Response::success(['withdrawn' => true]);
