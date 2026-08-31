<?php
/**
 * The tablet reports in.
 *
 * This is the single point where three different "stop serving employees"
 * conditions take effect, which is why the kiosk calls it on launch and
 * periodically thereafter:
 *
 *   401  the token was revoked, or the station was unpaired  -> wipe and re-pair
 *   426  this build is below medjat_kiosk_min_version        -> supervisor must update
 *   503  maintenance is on for the kiosk app                 -> wait it out
 *
 * A revoked tablet cannot be told anything while it is switched off, so
 * revocation is honest about being effective on the device's NEXT contact —
 * which is here.
 *
 * Input: app_version
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

// Resolves the token, rejects revoked stations with 401, and stamps last_seen_at
// (which is what the dark-kiosk alert reads).
$kiosk = Auth::authenticateKiosk(db());

$tenantId  = $kiosk['tenant_id'];
$branchId  = $kiosk['branch_id'];
$appVersion = isset($kiosk['input']['app_version'])
    ? (string) $kiosk['input']['app_version']
    : ($kiosk['station']['app_version'] ?? '0.0.0');

// Cached and fail-open: a Firebase outage must not stop every kiosk in every
// company from recording attendance.
$gate = RemoteConfigService::gateFor('medjat_kiosk');

if (!empty($gate['maintenance'])) {
    Response::fail(I18n::t('kiosk_maintenance'), 503, 'kiosk_maintenance');
}

if (RemoteConfigService::isBelow($appVersion, $gate['min_version'])) {
    // 426 Upgrade Required. The message is addressed to a supervisor, not to
    // the employee standing at the door — a directly-installed kiosk has no
    // store to send anybody to.
    Response::fail(
        I18n::t('kiosk_update_required'),
        426,
        'kiosk_update_required',
        ['min_version' => $gate['min_version'], 'current_version' => $appVersion]
    );
}

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch) {
    // The branch was deleted underneath a live kiosk.
    KioskStationModel::revoke($kiosk['station_id'], $tenantId, null);
    Response::fail(I18n::t('kiosk_token_invalid'), 401, 'kiosk_token_invalid');
}

if (empty($branch['station_enabled'])) {
    Response::fail(I18n::t('kiosk_pair_branch_disabled'), 403, 'kiosk_pair_branch_disabled');
}

$faceSettings = FaceMatchService::settingsFor($branch, $tenantId);

Response::success([
    'station_status' => 'active',
    'station' => [
        'id'   => $kiosk['station_id'],
        'name' => $kiosk['station']['station_name'] ?? null,
    ],
    'branch' => [
        'id'   => (int) $branch['id'],
        'name' => $branch['name'],
    ],
    // Tenant-zone time. A cheap tablet with no SIM keeps a wrong clock, and the
    // kiosk must never render its own.
    'server_time' => TenantClock::now($tenantId)->format(DATE_ATOM),
    'settings' => [
        'code_fallback_enabled'     => (bool) ($branch['station_code_fallback_enabled'] ?? 1),
        'anti_spoofing_enabled'     => (bool) ($branch['station_anti_spoofing_enabled'] ?? 1),
        'liveness_required'         => (bool) ($faceSettings['liveness_required'] ?? true),
        'gps_radius_meters'         => (int) ($branch['station_gps_radius_meters'] ?? 30),
        'branch_latitude'           => $branch['latitude'] !== null ? (float) $branch['latitude'] : null,
        'branch_longitude'          => $branch['longitude'] !== null ? (float) $branch['longitude'] : null,
        'min_seconds_between_punches' => 60,
    ],
]);
