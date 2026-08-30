<?php
/**
 * Take a tablet out of service.
 *
 * Sets the station to `revoked` and stamps its live token. The station ROW
 * survives — `attendance.station_id` points at it, and attendance recorded last
 * month must still resolve to the device that recorded it long after that
 * device has been retired or stolen.
 *
 * Effective on the tablet's next request, which is the honest guarantee: a
 * device that is switched off or offline cannot be told anything. That is
 * enough for the case this exists for — a stolen tablet is useless the moment it
 * next reaches the network.
 *
 * Input: station_id (required), reason (optional, for the audit trail)
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'kiosk_devices');

$stationId = (int) ($auth['input']['station_id'] ?? 0);
Validator::required($stationId, 'station_id');

$station = KioskStationModel::findById($stationId, $tenantId);
if (!$station) {
    Response::notFound('Kiosk');
}

if ($station['status'] === 'revoked') {
    // Idempotent: revoking twice is a supervisor tapping again, not an error.
    Response::success([
        'station_id' => $stationId,
        'status'     => 'revoked',
        'revoked_at' => $station['revoked_at'],
        'already_revoked' => true,
    ]);
}

$ok = KioskStationModel::revoke($stationId, $tenantId, (int) $auth['admin_id']);
if (!$ok) {
    Response::fail('Could not revoke this kiosk', 409, 'kiosk_revoke_failed');
}

Response::success([
    'station_id' => $stationId,
    'status'     => 'revoked',
    'already_revoked' => false,
]);
