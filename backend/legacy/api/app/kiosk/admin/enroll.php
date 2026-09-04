<?php
/**
 * Enrol an employee's face at the kiosk.
 *
 * This is what makes the feature self-contained for the person it exists for.
 * Every other enrollment path in Permedjat assumes a phone in the employee's hand;
 * a worker without a smartphone had no way to enrol a face at all, which meant
 * one-to-many identification could never recognise them.
 *
 * Writes the same `employees.face_*` columns as `app/biometric/enroll_face.php`,
 * so an enrollment captured here **is** the enrollment a selfie punch matches
 * against — not a parallel one.
 *
 * **Quality is judged on the server.** The tablet computes a score but does not
 * decide. A patched kiosk reporting perfect quality would poison the roster it
 * later matches against, and a bad enrollment does not fail loudly — it quietly
 * stops matching its owner and starts resembling other people.
 *
 * Input: employee_id, embedding[], model_version, quality_score,
 *        image, confirm_replace
 */
require_once __DIR__ . '/../../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$kiosk = Auth::authenticateKiosk(db());

$sessionToken = $_SERVER['HTTP_X_KIOSK_ADMIN_SESSION'] ?? ($kiosk['input']['admin_session'] ?? '');
$station = KioskPairing::touchAdminSession($kiosk['station_id'], (string) $sessionToken);
if (!$station) {
    Response::fail(I18n::t('kiosk_admin_session_expired'), 401, 'kiosk_admin_session_expired');
}

$tenantId = $kiosk['tenant_id'];
$branchId = $kiosk['branch_id'];
$input    = $kiosk['input'];

$employeeId = (int) ($input['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee || (int) ($employee['branch_id'] ?? 0) !== $branchId) {
    // Not "forbidden": from the tablet's point of view this employee simply is
    // not on its roster, and it was never offered them.
    Response::notFound('Employee');
}
if (($employee['status'] ?? '') === 'terminated') {
    Response::fail(I18n::t('account_suspended'), 403, 'account_suspended');
}

// ---- Model and embedding ----------------------------------------------------
$modelVersion = (string) ($input['model_version'] ?? '');
if ($modelVersion !== FaceMatchService::MODEL_VERSION) {
    Response::fail(I18n::t('kiosk_quality_low'), 422, 'model_mismatch');
}

$vector = FaceMatchService::parseEmbedding($input['embedding'] ?? null);
if ($vector === null) {
    Response::fail(I18n::t('kiosk_quality_low'), 422, 'bad_embedding');
}

// ---- Quality, decided here and not on the tablet ----------------------------
$quality = isset($input['quality_score']) ? (float) $input['quality_score'] : 0.0;
if ($quality < BiometricEnrollment::MIN_QUALITY_SCORE) {
    StationRecognitionLogModel::record([
        'tenant_id'  => $tenantId,
        'station_id' => $kiosk['station_id'],
        'branch_id'  => $branchId,
        'employee_id'=> $employeeId,
        'purpose'    => 'enroll',
        'method'     => 'face',
        'result'     => 'not_enrolled',
        'accepted'   => false,
        'match_score'=> $quality,
    ]);

    Response::fail(I18n::t('kiosk_quality_low'), 422, 'quality_too_low', [
        'quality_score' => $quality,
        'minimum'       => BiometricEnrollment::MIN_QUALITY_SCORE,
    ]);
}

// ---- Re-enrollment is an explicit act ---------------------------------------
// Without this, a second person enrolled onto an existing employee is a silent
// overwrite — and afterwards nothing distinguishes it from the original.
$alreadyEnrolled = !empty($employee['face_embedding']);
if ($alreadyEnrolled && empty($input['confirm_replace'])) {
    Response::fail(I18n::t('kiosk_enroll_replaced'), 409, 'kiosk_enroll_replaced', [
        'enrolled_at'   => $employee['face_enrolled_at'],
        'quality_score' => $employee['face_quality_score'] !== null
            ? (float) $employee['face_quality_score'] : null,
    ]);
}

$photoUrl = BiometricEnrollment::storeReferencePhoto(
    $input['image'] ?? null,
    $tenantId,
    $employeeId
);

BiometricModel::enrollFace(
    $employeeId,
    $tenantId,
    json_encode($vector),
    $photoUrl,
    $quality,
    $modelVersion,
    count($vector)
);

// Provenance: which kiosk performed it. The administrator who authorised the
// session is already on the station row.
Database::execute(
    "UPDATE employees SET face_enrolled_by_station_id = ? WHERE id = ? AND tenant_id = ?",
    [$kiosk['station_id'], $employeeId, $tenantId]
);

StationRecognitionLogModel::record([
    'tenant_id'  => $tenantId,
    'station_id' => $kiosk['station_id'],
    'branch_id'  => $branchId,
    'employee_id'=> $employeeId,
    'purpose'    => 'enroll',
    'method'     => 'face',
    'result'     => 'matched',
    'accepted'   => true,
    'match_score'=> $quality,
]);

Response::success([
    'employee_id'       => $employeeId,
    'name'              => $employee['name'],
    'enrolled_at'       => TenantClock::now($tenantId)->format(DATE_ATOM),
    'replaced_previous' => $alreadyEnrolled,
    'authorised_by'     => (int) ($station['admin_session_by'] ?? 0),
    'message_key'       => 'kiosk_enroll_done',
]);
