<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_schedule');
$input = $auth['input'];

Validator::required($input['claim_id'] ?? null, 'claim_id');
Validator::required($input['decision'] ?? null, 'decision');
Validator::enum($input['decision'], ['approve', 'reject'], 'decision');

$claimId = (int) $input['claim_id'];
$decision = $input['decision'];

$claim = OpenShiftModel::findClaim($claimId, $tenantId);
if (!$claim) Response::notFound('Claim');

$openShift = OpenShiftModel::findById((int) $claim['open_shift_id'], $tenantId);
if ($openShift && $openShift['branch_id'] !== null) {
    PermissionMiddleware::checkBranchAccess($auth, (int) $openShift['branch_id']);
}

if ($decision === 'approve') {
    $result = OpenShiftModel::approveClaim($tenantId, $claimId, (int) $auth['admin_id']);
    AuditLogModel::log($tenantId, $auth['admin_id'], 'schedule.open_shift_approve', 'open_shift_claim', $claimId, $result);
    Response::success($result);
} else {
    OpenShiftModel::rejectClaim($tenantId, $claimId, (int) $auth['admin_id']);
    AuditLogModel::log($tenantId, $auth['admin_id'], 'schedule.open_shift_reject', 'open_shift_claim', $claimId);
    Response::success(['rejected' => true]);
}
