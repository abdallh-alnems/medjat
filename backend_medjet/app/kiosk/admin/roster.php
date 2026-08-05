<?php
/**
 * Who can be enrolled at this tablet.
 *
 * Scoped server-side to the station's branch and to employees who are not
 * terminated. Filtering in the UI instead would leave the endpoint willing to
 * enrol anybody in the company from any branch's tablet.
 *
 * Unenrolled people sort first, because that is the actual job on a first
 * morning with forty workers queuing at a door.
 */
require_once __DIR__ . '/../../../config/bootstrap.php';
require_once __DIR__ . '/../../../core/KioskPairing.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$kiosk = Auth::authenticateKiosk(db());

$sessionToken = $_SERVER['HTTP_X_KIOSK_ADMIN_SESSION'] ?? ($kiosk['input']['admin_session'] ?? '');
if (!KioskPairing::touchAdminSession($kiosk['station_id'], (string) $sessionToken)) {
    Response::fail(I18n::t('kiosk_admin_session_expired'), 401, 'kiosk_admin_session_expired');
}

$employees = Database::fetchAll(
    "SELECT id, name, job_title, face_enrolled_at, face_quality_score,
            (face_embedding IS NOT NULL) AS face_enrolled,
            (kiosk_pin_hash IS NOT NULL) AS has_kiosk_code
       FROM employees
      WHERE tenant_id = ? AND branch_id = ? AND status <> 'terminated'
      ORDER BY (face_embedding IS NOT NULL) ASC, name ASC",
    [$kiosk['tenant_id'], $kiosk['branch_id']]
);

Response::success([
    'employees' => array_map(static fn(array $e): array => [
        'id'            => (int) $e['id'],
        'name'          => $e['name'],
        'job_title'     => $e['job_title'] ?? null,
        'face_enrolled' => (bool) $e['face_enrolled'],
        'enrolled_at'   => $e['face_enrolled_at'],
        'quality_score' => $e['face_quality_score'] !== null ? (float) $e['face_quality_score'] : null,
        'has_kiosk_code'=> (bool) $e['has_kiosk_code'],
    ], $employees),
    'model_version' => FaceMatchService::MODEL_VERSION,
]);
