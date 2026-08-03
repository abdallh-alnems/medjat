<?php
/**
 * Issues a single-use liveness challenge for face check-in / check-out /
 * enrollment.
 *
 * The employee app calls this immediately before opening the camera, performs
 * the returned action (blink / turn / smile), and sends the nonce back with the
 * embedding. The nonce is what stops a captured embedding from being replayed.
 *
 * Input:  purpose (check_in|check_out|enroll)
 * Output: nonce, challenge, expires_in, liveness_required
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];

$input = $auth['input'];
$purpose = $input['purpose'] ?? 'check_in';

if (!in_array($purpose, ['check_in', 'check_out', 'enroll'], true)) {
    Response::fail('purpose must be check_in, check_out or enroll', 422, 'invalid_purpose');
}

// Enrollment is the one purpose that does not require an existing enrollment;
// the other two are pointless without one, so fail early with a clear code
// rather than letting the check-in itself reject later.
if ($purpose !== 'enroll' && empty($employee['face_embedding'])) {
    Response::fail(I18n::t('face_not_enrolled'), 400, 'FACE_NOT_ENROLLED');
}

$branch = null;
$branchId = (int) ($employee['branch_id'] ?? 0);
if ($branchId > 0) {
    $branch = BranchModel::findById($branchId, $tenantId);
}
$settings = FaceMatchService::settingsFor($branch, $tenantId);

$challenge = FaceChallengeModel::issue($tenantId, (int) $employee['id'], $purpose);

Response::success([
    'nonce' => $challenge['nonce'],
    'challenge' => $challenge['challenge'],
    'expires_in' => $challenge['expires_in'],
    'liveness_required' => $settings['liveness_required'],
    'model_version' => FaceMatchService::MODEL_VERSION,
]);
