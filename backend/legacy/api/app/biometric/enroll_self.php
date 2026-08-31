<?php
/**
 * Employee self-enrollment of their own face, from the employee app.
 *
 * Why self-service rather than HR-driven: only the employee app ships the
 * embedding model, and re-enrolling every employee through an HR device does
 * not scale. HR keeps control in two ways — the enrolled reference photo is
 * visible on the employee profile, and enrollment is one-time: changing it
 * requires an HR reset via app/biometric/delete.php.
 *
 * Input:  embedding, image_base64, quality_score, face_nonce, liveness_passed
 * Output: status, enrolled_at
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];
$employeeId = (int) $employee['id'];
$input = $auth['input'];

// One-time by design: a second enrollment would let someone quietly replace
// the reference face after the first one was approved.
if (!empty($employee['face_embedding'])) {
    $storedVersion = $employee['face_model_version'] ?? null;
    $staleModel = $storedVersion !== null && $storedVersion !== FaceMatchService::MODEL_VERSION;
    if (!$staleModel) {
        Response::fail(I18n::t('face_already_enrolled'), 409, 'FACE_ALREADY_ENROLLED');
    }
    // A model upgrade is the one case where re-enrollment is allowed without
    // an HR reset: the old embedding is unusable anyway.
}

$branchId = (int) ($employee['branch_id'] ?? 0);
$branch = $branchId > 0 ? BranchModel::findById($branchId, $tenantId) : null;
$settings = FaceMatchService::settingsFor($branch, $tenantId);

// Enrollment must clear the same liveness bar as a check-in, otherwise someone
// could enrol a printed photo and every later match would be against it.
$challenge = FaceChallengeModel::consume(
    (string) ($input['face_nonce'] ?? ''),
    $tenantId,
    $employeeId,
    'enroll'
);
if ($challenge === null) {
    Response::fail(I18n::t('face_challenge_expired'), 400, 'FACE_INVALID_CHALLENGE');
}

if ($settings['liveness_required'] && empty($input['liveness_passed'])) {
    Response::fail(I18n::t('face_liveness_failed'), 403, 'FACE_LIVENESS_FAILED');
}

$vector = FaceMatchService::parseEmbedding($input['embedding'] ?? null);
if ($vector === null) {
    Response::fail(I18n::t('face_capture_failed'), 422, 'FACE_BAD_EMBEDDING');
}

$qualityScore = (float) ($input['quality_score'] ?? 0);
if ($qualityScore < BiometricEnrollment::MIN_QUALITY_SCORE) {
    Response::fail(I18n::t('face_quality_too_low'), 422, 'FACE_QUALITY_TOO_LOW');
}

$photoUrl = BiometricEnrollment::storeReferencePhoto($input['image_base64'] ?? null, $tenantId, $employeeId);

BiometricModel::enrollFace(
    $employeeId,
    $tenantId,
    json_encode($vector),
    $photoUrl,
    $qualityScore,
    FaceMatchService::MODEL_VERSION,
    count($vector)
);

AuditLogModel::log($tenantId, null, 'biometric.self_enroll_face', 'employee', $employeeId);

Response::success([
    'status' => 'face_enrolled',
    'enrolled_at' => date('Y-m-d H:i:s'),
    'model_version' => FaceMatchService::MODEL_VERSION,
], 201);
