<?php
/**
 * Close the administration area, and optionally release kiosk mode.
 *
 * `release_kiosk_mode` is how a supervisor unpins the tablet to change the
 * WiFi, move it to another branch, or hand it back. It is reachable **only**
 * from inside an authorised session, which is the whole reason kiosk-mode
 * release costs an access code rather than the static per-branch PIN the old
 * `station_admin_pin_hash` column was built for.
 *
 * Input: release_kiosk_mode (bool)
 */
require_once __DIR__ . '/../../../config/bootstrap.php';
require_once __DIR__ . '/../../../core/KioskPairing.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$kiosk = Auth::authenticateKiosk(db());

$sessionToken = $_SERVER['HTTP_X_KIOSK_ADMIN_SESSION'] ?? ($kiosk['input']['admin_session'] ?? '');
if (!KioskPairing::touchAdminSession($kiosk['station_id'], (string) $sessionToken)) {
    // Already closed or expired. Idempotent: a supervisor tapping "done" on a
    // session that timed out has achieved what they wanted.
    Response::success(['closed' => true, 'already_closed' => true]);
}

KioskPairing::closeAdminSession($kiosk['station_id']);

Response::success([
    'closed'             => true,
    'already_closed'     => false,
    'release_kiosk_mode' => !empty($kiosk['input']['release_kiosk_mode']),
]);
