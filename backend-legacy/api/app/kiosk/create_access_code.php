<?php
/**
 * Generate the code that opens a kiosk's administration area.
 *
 * Six digits, five minutes, single use. Short because a supervisor reads it off
 * a phone and types it on a tablet immediately; safe because it is spent on
 * first use and expires before it can be written on a sticky note.
 *
 * Gated by `kiosk_access`, deliberately NOT `kiosk_devices`. Generating one of
 * these is a daily task for a branch manager; pairing and unpairing hardware is
 * not, and someone who can enrol a face should not thereby be able to unpair
 * the fleet.
 *
 * Input: station_id (required)
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'kiosk_access');

$stationId = (int) ($auth['input']['station_id'] ?? 0);
Validator::required($stationId, 'station_id');

$station = KioskStationModel::findById($stationId, $tenantId);
if (!$station) {
    Response::notFound('Kiosk');
}

if ($station['status'] !== 'active') {
    Response::fail(I18n::t('kiosk_token_invalid'), 409, 'kiosk_revoked');
}

$issued = KioskPairing::issueAccessCode(
    $tenantId,
    (int) $station['branch_id'],
    $stationId,
    (int) $auth['admin_id']
);

Response::success([
    'code'               => $issued['code'],
    'expires_at'         => $issued['expires_at'],
    'expires_in_seconds' => KioskPairing::ACCESS_TTL_SECONDS,
    'station'            => ['id' => $stationId, 'name' => $station['name']],
]);
