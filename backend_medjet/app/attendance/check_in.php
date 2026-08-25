<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];

$input = $auth['input'];
$branchId = (int) ($input['branch_id'] ?? 0);
$latitude = (float) ($input['latitude'] ?? 0);
$longitude = (float) ($input['longitude'] ?? 0);
$qrCode = $input['qr_code'] ?? null;
$isVpn = isset($input['is_vpn']) && (int) $input['is_vpn'] === 1;
$isMockLocation = isset($input['is_mock_location']) && (int) $input['is_mock_location'] === 1;

Validator::required($branchId, 'branch_id');

$employee = $auth['employee'];

// The channel comes from the authenticated session, never from the request
// body. A body field could be forged to make a browser punch present itself as
// an app punch, laundering it past a company that restricted the channel.
$isWeb = ($auth['platform'] ?? null) === 'web';
$origin = $isWeb ? 'web' : 'app';

if ($isWeb) {
    WebSessionService::enforcePerEmployeeLimit($auth);
    $access = WebAccessPolicy::check($employee, $tenantId);
    if (!$access['allowed']) {
        WebAccessPolicy::refuse($tenantId, (int) $employee['id'], $access['reason'], $branchId, $latitude ?: null, $longitude ?: null);
    }
}

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch) {
    Response::fail('Branch not found', 404, 'BRANCH_NOT_FOUND');
}

// Enforce the attendance method configured for this branch. Self check-in
// from the employee app is only valid for qr_gps / gps_only / face_selfie /
// wifi_gps; manual is handled elsewhere (admin records it).
$methods = AttendanceMethodResolver::resolveForEmployee($employee, $tenantId);

// Older app builds don't send `method` — infer it from the QR as before.
$requestedMethod = $input['method'] ?? ($qrCode ? 'qr_gps' : 'gps_only');
if (!in_array($requestedMethod, AttendanceMethodResolver::SELF_SERVICE, true)) {
    Response::fail('Unsupported check-in method', 422, 'METHOD_NOT_ALLOWED');
}

if (!in_array($requestedMethod, $methods, true)) {
    if ($requestedMethod === 'qr_gps' && in_array('gps_only', $methods, true)) {
        Response::fail('QR check-in is not enabled for this branch', 403, 'METHOD_NOT_ALLOWED');
    }
    if ($requestedMethod === 'gps_only' && in_array('qr_gps', $methods, true)) {
        Response::fail('QR code is required for this branch', 400, 'QR_REQUIRED');
    }
    Response::fail('Self check-in is disabled for this branch', 403, 'METHOD_NOT_ALLOWED');
}

// Device-biometric gate. This is the cheapest check on the path — a boolean —
// so it rejects before any QR, GPS or face work is done. It answers the one
// question every other control on this endpoint takes for granted: whether the
// person tapping is the person the phone belongs to. Opt-in per company, and
// only enforced when opted in, because older app builds never send the field.
if (TenantModel::requiresLocalBiometric($tenantId)
    && (int) ($input['local_biometric'] ?? 0) !== 1) {
    AttendanceSecurityModel::log(
        $tenantId,
        (int) $employee['id'],
        $branchId,
        'no_local_biometric',
        'blocked',
        $latitude ?: null,
        $longitude ?: null
    );
    Response::fail(I18n::t('local_biometric_required'), 403, 'LOCAL_BIOMETRIC_REQUIRED');
}

// A branch on rotating codes does not accept its printed one, and vice versa.
// Both paths stay because the flag is per branch: one branch can be on a screen
// while the branch down the road is still on a laminated sheet.
//
// No app release is involved either way. The employee app forwards whatever the
// camera read (scan_qr_screen -> processQrScan -> 'qr_code') and has never
// interpreted the value, so builds already in the stores send a rotating code
// exactly as they sent a printed one. The server decides which it expects.
$rotatingQr = $requestedMethod === 'qr_gps'
    && BranchQrChallengeModel::isEnabledForBranch($branch);

if ($rotatingQr) {
    // Say so before the geofence is evaluated: an employee who sent nothing to
    // scan should be told to look at the screen, not told they are out of range.
    if (!is_string($qrCode) || $qrCode === '') {
        Response::fail(I18n::t('qr_rotating_required'), 400, 'QR_REQUIRED');
    }
} elseif ($qrCode && $branch['qr_code'] !== $qrCode) {
    Response::fail('Invalid QR code for this branch', 400, 'INVALID_QR');
}

// Both qr_gps and gps_only require GPS, so the employee must send a real
// location. Missing/denied location reads as 0,0 — reject it instead of
// letting a QR code pass without any GPS verification.
if ($latitude == 0.0 && $longitude == 0.0) {
    Response::fail('Location is required for check-in', 400, 'LOCATION_REQUIRED');
}

// A mocked location invalidates the geofence entirely, so this runs before it
// rather than after. The app refuses to get this far on its own, but that check
// lives on the employee's phone — this is the one the employee cannot remove.
// Opt-in per company, and only meaningful on Android (iOS never reports it).
if ($isMockLocation && TenantModel::rejectsMockLocation($tenantId)) {
    AttendanceSecurityModel::log(
        $tenantId,
        (int) $employee['id'],
        $branchId,
        'mock_location',
        'blocked',
        $latitude ?: null,
        $longitude ?: null
    );
    Response::fail(I18n::t('mock_location_rejected'), 403, 'MOCK_LOCATION');
}

$gpsResult = GpsService::validateCheckIn($latitude, $longitude, $branchId, $tenantId);

// The network sighting is recorded BEFORE the GPS verdict, and regardless of
// it. "Someone tried from outside the geofence on network X" is exactly the
// signal the approval screen needs to keep an employee's home router out of
// the branch's approved list.
if ($requestedMethod === 'wifi_gps') {
    NetworkVerifier::recordSighting(
        $tenantId,
        $branchId,
        (int) $employee['id'],
        $input,
        (bool) $gpsResult['valid'],
        $gpsResult['distance'] !== null ? (float) $gpsResult['distance'] : null
    );
}

if (!$gpsResult['valid']) {
    Response::fail($gpsResult['message'], 400, $gpsResult['reason'] ?? 'GPS_OUT_OF_RANGE');
}

// WiFi is an additional constraint on top of the geofence, never a substitute:
// GPS drifts indoors, and the WiFi signal leaks outdoors.
if ($requestedMethod === 'wifi_gps') {
    $network = NetworkVerifier::verify($branch, $input);
    if (!$network['accepted']) {
        Response::fail($network['message'], 403, 'WIFI_' . strtoupper($network['reason']));
    }
}

// The browser channel's network control. spec 004 counts network restriction
// among the compensating controls that make the weakest channel acceptable, and
// web_status.php has been announcing it to the page since day one — but nothing
// applied it here, because the only call to NetworkVerifier on this path is
// gated on wifi_gps and a browser never sends that method. The control existed
// on the screen and nowhere else.
//
// verifyBrowser(), not verify(): a page cannot report a BSSID, so the ordinary
// path would refuse every web punch at an enforcing branch instead of
// constraining it. See core/NetworkVerifier.php.
if ($isWeb) {
    $webNetwork = NetworkVerifier::verifyBrowser($branch);
    if (!$webNetwork['accepted']) {
        AttendanceSecurityModel::log(
            $tenantId,
            (int) $employee['id'],
            $branchId,
            $webNetwork['reason'],
            'blocked',
            $latitude ?: null,
            $longitude ?: null
        );
        Response::fail($webNetwork['message'], 403, 'WEB_WRONG_NETWORK');
    }
}

// Rotating QR is claimed after the geofence for the same reason the face check
// is: spending a code writes a row, and an employee standing outside the radius
// must not burn one they will need thirty seconds later when they walk in.
if ($rotatingQr) {
    $claim = BranchQrChallengeModel::consume(
        (string) $qrCode,
        $tenantId,
        $branchId,
        (int) $employee['id'],
        'check_in'
    );

    if (!$claim['ok']) {
        // A replay is a forwarded screenshot; an expiry is usually a slow scan.
        // Both are recorded, because a run of expiries at one branch is how a
        // dead display announces itself.
        AttendanceSecurityModel::log(
            $tenantId,
            (int) $employee['id'],
            $branchId,
            $claim['reason'],
            'blocked',
            $latitude ?: null,
            $longitude ?: null
        );
        Response::fail(I18n::t($claim['reason']), 403, strtoupper($claim['reason']));
    }
}

// Face verification runs after GPS so an out-of-range employee never burns a
// liveness challenge, and the cheap check rejects first.
$faceScore = null;
if ($requestedMethod === 'face_selfie') {
    $verification = FaceMatchService::verify(
        $employee,
        $tenantId,
        $branch,
        'check_in',
        $input,
        $latitude ?: null,
        $longitude ?: null
    );

    if (!$verification['accepted']) {
        Response::fail(
            $verification['message'],
            403,
            'FACE_' . strtoupper($verification['result']),
            ['score' => $verification['score'], 'threshold' => $verification['threshold']]
        );
    }

    $faceScore = $verification['score'];
}

// Evidence is captured before the punch is written, so a company that requires
// a photo never ends up with attendance recorded without one. Refusing here
// rather than recording anyway matters: silently dropping the image would
// remove a control the company deliberately switched on, and nobody would
// notice until they went looking for a picture that was never taken.
// Two independent reasons to hold an image, and they are not the same rule.
// photo_gps is a method the company chose *because* it wants a photograph and
// no biometric processing; the browser rule is a property of the weakest
// channel. A company can be on both at once, so this is an OR, not a branch.
$punchPhoto = null;
$photoRequired = $requestedMethod === 'photo_gps'
    || ($isWeb && WebAccessPolicy::photoRequired($tenantId));

if ($photoRequired) {
    $punchPhoto = PunchPhotoService::store($input['photo_base64'] ?? null, $tenantId, (int) $employee['id']);
    if ($punchPhoto === null) {
        Response::fail(
            I18n::t($isWeb ? 'web_photo_required' : 'photo_required'),
            422,
            'PHOTO_REQUIRED'
        );
    }
}

AttendanceModel::checkIn(
    $employee['id'],
    $branchId,
    $tenantId,
    $requestedMethod,
    null,
    $latitude ?: null,
    $longitude ?: null,
    $isVpn,
    $requestedMethod === 'face_selfie' ? 'mobile_face' : null,
    $faceScore
);

$tenantToday = TenantClock::date($tenantId);
AttendanceModel::recordChannel($tenantId, (int) $employee['id'], $tenantToday, 'check_in', $origin, $punchPhoto);

if ($isWeb) {
    // Flags, never blocks. No non-biometric control can prevent a colleague
    // punching for a willing employee, so the design makes the pattern visible
    // instead of pretending it is stopped.
    $others = SharedDeviceDetector::otherEmployeesOnDevice(
        $tenantId,
        (string) ($auth['device_id'] ?? ''),
        (int) $employee['id'],
        $tenantToday
    );
    SharedDeviceDetector::flag($tenantId, $tenantToday, (int) $employee['id'], $others, $branchId);
}

if ($isVpn) {
    try {
        AttendanceSecurityModel::log($tenantId, (int) $employee['id'], $branchId, 'vpn', 'flagged', $latitude ?: null, $longitude ?: null);
    } catch (Exception $e) {
        error_log('VPN security log failed: ' . $e->getMessage());
    }
}

Response::success([
    'message' => 'Check-in successful',
    // The tenant's wall clock, matching what was just stored.
    'time' => TenantClock::time($tenantId),
    'branch' => $branch['name'],
]);
