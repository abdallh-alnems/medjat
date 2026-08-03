<?php
/**
 * The employee's own face-enrollment status, for the employee app.
 *
 * The app calls this on the attendance screen to decide whether to send the
 * employee to enrollment or straight to the face check-in camera.
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];

$branchId = (int) ($employee['branch_id'] ?? 0);
$branch = $branchId > 0 ? BranchModel::findById($branchId, $tenantId) : null;
$settings = FaceMatchService::settingsFor($branch, $tenantId);

$enrolled = !empty($employee['face_embedding']);
$storedVersion = $employee['face_model_version'] ?? null;
$needsReenrollment = $enrolled
    && $storedVersion !== null
    && $storedVersion !== FaceMatchService::MODEL_VERSION;

Response::success([
    'enrolled' => $enrolled && !$needsReenrollment,
    'needs_reenrollment' => $needsReenrollment,
    'enrolled_at' => $employee['face_enrolled_at'] ?? null,
    'model_version' => FaceMatchService::MODEL_VERSION,
    'liveness_required' => $settings['liveness_required'],
    'min_quality_score' => BiometricEnrollment::MIN_QUALITY_SCORE,
]);
