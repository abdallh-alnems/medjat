<?php
/**
 * Manual capture: an admin standing in the branch presses a button and the
 * access point they are connected to is approved.
 *
 * The geofence guard is the important part. If an admin captured their home
 * router by mistake, that home would become the branch's valid location and the
 * office would be locked out — so the capture is rejected unless the admin's
 * GPS puts them inside the branch.
 *
 * Note this only ever captures ONE BSSID: the one radio the admin's phone
 * happens to be on. A dual-band router broadcasts a separate BSSID per band
 * (plus one per guest SSID), so a branch normally needs several. Learning mode
 * discovers them all from real check-ins; this endpoint is the quick path for a
 * brand-new branch with no history yet.
 *
 * Input:  branch_id, bssid, ssid, latitude, longitude, label
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_company_settings');

$input = $auth['input'];
$branchId = (int) ($input['branch_id'] ?? 0);
Validator::required($branchId, 'branch_id');

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch) {
    Response::notFound('Branch');
}
PermissionMiddleware::checkBranchAccess($auth, $branchId);

$bssid = NetworkVerifier::normaliseBssid($input['bssid'] ?? null);
if ($bssid === null) {
    // Also the path for an Android device with location switched off, which
    // reports the 02:00:00:00:00:00 sentinel rather than a real address.
    Response::fail(I18n::t('wifi_not_connected'), 422, 'WIFI_NOT_CONNECTED');
}

$latitude = (float) ($input['latitude'] ?? 0);
$longitude = (float) ($input['longitude'] ?? 0);
if ($latitude == 0.0 && $longitude == 0.0) {
    Response::fail('Location is required to capture a branch network', 400, 'LOCATION_REQUIRED');
}

$gps = GpsService::validateCheckIn($latitude, $longitude, $branchId, $tenantId);
if (!$gps['valid']) {
    Response::fail(
        I18n::t('wifi_capture_outside_branch'),
        403,
        'CAPTURE_OUTSIDE_BRANCH',
        ['distance' => $gps['distance'], 'allowed_radius' => $gps['allowed_radius']]
    );
}

$ssid = isset($input['ssid']) ? mb_substr((string) $input['ssid'], 0, 100) : null;
$label = isset($input['label']) ? mb_substr((string) $input['label'], 0, 100) : null;

BranchNetworkModel::approve(
    $tenantId,
    $branchId,
    'bssid',
    $bssid,
    ($label !== null && $label !== '') ? $label : (($ssid !== null && $ssid !== '') ? $ssid : null),
    'captured',
    $auth['admin_id']
);

// A branch capturing its first network has clearly opted in, so start it in
// learning mode rather than leaving wifi_mode NULL — the remaining access
// points still need discovering before enforcement makes sense.
if (($branch['wifi_mode'] ?? null) === null) {
    BranchModel::updateWifiSettings($branchId, $tenantId, 'learning', $branch['wifi_match'] ?? 'bssid');
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'branch.capture_network', 'branch', $branchId, [
    'bssid' => $bssid,
    'ssid' => $ssid,
]);

Response::success([
    'bssid' => $bssid,
    'ssid' => $ssid,
    'networks' => BranchNetworkModel::approvedFor($branchId, $tenantId),
]);
