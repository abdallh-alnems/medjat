<?php
/**
 * Redeem a pairing code: turn an unconfigured tablet into a branch kiosk.
 *
 * **The only kiosk endpoint that accepts an unauthenticated request.** The code
 * IS the credential here, which is why it is single-use, short-lived, and why
 * this endpoint is rate limited per IP — it is the one door into the kiosk
 * surface that is not already behind a token.
 *
 * Unknown, expired, and already-consumed codes all return the same 410 with the
 * same message. Distinguishing them would turn this into an oracle: an attacker
 * could tell a real-but-spent code from a wrong guess and learn the alphabet.
 *
 * Input: code, device_id, device_model, app_version, platform, name
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true) ?: [];

$code     = trim((string) ($input['code'] ?? ''));
$deviceId = trim((string) ($input['device_id'] ?? ''));

Validator::required($code, 'code');
Validator::required($deviceId, 'device_id');

$deviceModel = isset($input['device_model']) ? substr((string) $input['device_model'], 0, 100) : null;
$appVersion  = isset($input['app_version'])  ? substr((string) $input['app_version'], 0, 20)  : null;
$platform    = ($input['platform'] ?? 'android') === 'ios' ? 'ios' : 'android';
$name        = isset($input['name']) && $input['name'] !== ''
    ? substr((string) $input['name'], 0, 100)
    : null;

// Atomic: lookup, expiry check, and consumption are one guarded UPDATE, so two
// tablets racing the same code cannot both pair.
$codeRow = KioskPairing::consume($code, 'pair');
if (!$codeRow) {
    Response::fail(I18n::t('kiosk_pair_code_spent'), 410, 'kiosk_pair_code_spent');
}

$branch = BranchModel::findById((int) $codeRow['branch_id'], (int) $codeRow['tenant_id']);
if (!$branch) {
    // The branch was deleted between issuing the code and redeeming it.
    Response::fail(I18n::t('kiosk_pair_branch_disabled'), 422, 'kiosk_pair_branch_disabled');
}

$paired = KioskPairing::pairDevice(
    $codeRow,
    $deviceId,
    $deviceModel,
    $platform,
    $appVersion,
    $name ?? $branch['name']
);

$tenant = TenantModel::findById((int) $codeRow['tenant_id']);

// The branch name goes back so the tablet can confirm on screen what it has
// become. A supervisor pairing five devices needs to see which is which before
// mounting them on walls.
Response::success([
    'kiosk_token' => $paired['token'],
    'station' => [
        'id'   => $paired['station_id'],
        'name' => $name ?? $branch['name'],
    ],
    'branch' => [
        'id'                        => (int) $branch['id'],
        'name'                      => $branch['name'],
        'latitude'                  => $branch['latitude'] !== null ? (float) $branch['latitude'] : null,
        'longitude'                 => $branch['longitude'] !== null ? (float) $branch['longitude'] : null,
        'station_gps_radius_meters' => (int) ($branch['station_gps_radius_meters'] ?? 30),
    ],
    'tenant' => [
        'id'       => (int) $codeRow['tenant_id'],
        'name'     => $tenant['name'] ?? null,
        'timezone' => $tenant['timezone'] ?? 'Africa/Cairo',
    ],
]);
