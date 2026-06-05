<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_recruitment');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
$stage = $input['stage'] ?? '';
Validator::required($id, 'id');
Validator::required($stage, 'stage');

$stage = Validator::enum($stage, CandidateModel::STAGES, 'stage');

if ($stage === 'hired') {
    Response::fail('Use candidate_convert to hire a candidate', 422);
}

$candidate = CandidateModel::findById($id, $tenantId);
if (!$candidate) {
    Response::notFound('Candidate');
}

$rejectionReason = null;
if ($stage === 'rejected') {
    $rejectionReason = trim((string) ($input['rejection_reason'] ?? ''));
    if ($rejectionReason === '') {
        Response::fail('rejection_reason is required when rejecting a candidate', 422);
    }
}

CandidateModel::updateStage($id, $tenantId, $stage, $rejectionReason);

AuditLogModel::log($tenantId, $auth['admin_id'], 'candidate.move_stage', 'candidate', $id, [
    'from' => $candidate['stage'],
    'to' => $stage,
]);

Response::success(['message' => 'Candidate stage updated']);
