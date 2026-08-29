<?php
/**
 * Redeem an access code to open the kiosk's administration area.
 *
 * Everything privileged on the tablet lives behind this one door: enrolling
 * faces, kiosk settings, and releasing kiosk mode. There is no static PIN — the
 * old `branches.station_admin_pin_hash` was built for one and is deliberately
 * unused, because a static PIN is shared once and then works forever.
 *
 * The code must belong to THIS station. An access code generated for the tablet
 * at one branch must not open the tablet at another, or a supervisor with
 * access to a quiet branch could enrol faces on a busy one.
 *
 * Input: code
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$kiosk = Auth::authenticateKiosk(db());

$code = trim((string) ($kiosk['input']['code'] ?? ''));
Validator::required($code, 'code');

$codeRow = KioskPairing::consume($code, 'access', $kiosk['station_id']);

// Unknown, expired, and already-spent all answer the same way: distinguishing
// them would let someone probing six digits tell a real code from a wrong one.
if (!$codeRow || (int) $codeRow['station_id'] !== $kiosk['station_id']) {
    Response::fail(I18n::t('kiosk_pair_code_spent'), 410, 'kiosk_pair_code_spent');
}

$session = KioskPairing::openAdminSession($kiosk['station_id'], (int) $codeRow['created_by']);

$admin = Database::fetchOne(
    "SELECT id, name FROM admins WHERE id = ? LIMIT 1",
    [(int) $codeRow['created_by']]
);

Response::success([
    'admin_session'      => $session,
    'expires_in_seconds' => KioskPairing::ADMIN_SESSION_TTL_SECONDS,
    // Carried onto every enrollment made in this session: the audit trail names
    // the administrator who authorised it, not the tablet.
    'authorised_by' => [
        'id'   => (int) $codeRow['created_by'],
        'name' => $admin['name'] ?? null,
    ],
]);
