<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];
$input = $auth['input'];

// Channel taken from the session, never the body — see check_in.php.
$isWeb = ($auth['platform'] ?? null) === 'web';
$origin = $isWeb ? 'web' : 'app';

if ($isWeb) {
    WebSessionService::enforcePerEmployeeLimit($auth);

    // A company that disables the channel mid-shift must still let an employee
    // close the day they already opened, so this permits check-out for anyone
    // holding a live web session and only refuses if the policy says no.
    $access = WebAccessPolicy::check($employee, $tenantId);
    if (!$access['allowed']) {
        WebAccessPolicy::refuse(
            $tenantId,
            (int) $employee['id'],
            $access['reason'],
            isset($employee['branch_id']) ? (int) $employee['branch_id'] : null,
            isset($input['latitude']) ? (float) $input['latitude'] : null,
            isset($input['longitude']) ? (float) $input['longitude'] : null
        );
    }
}

// Mock-location rejection mirrors check_in.php. Enforcing it only on check-in
// would leave the hole half open: an employee could arrive legitimately and
// then clock out from home on a spoofed location.
if (isset($input['is_mock_location']) && (int) $input['is_mock_location'] === 1
    && TenantModel::rejectsMockLocation($tenantId)) {
    AttendanceSecurityModel::log(
        $tenantId,
        (int) $employee['id'],
        isset($employee['branch_id']) ? (int) $employee['branch_id'] : null,
        'mock_location',
        'blocked',
        isset($input['latitude']) ? (float) $input['latitude'] : null,
        isset($input['longitude']) ? (float) $input['longitude'] : null
    );
    Response::fail(I18n::t('mock_location_rejected'), 403, 'MOCK_LOCATION');
}

// Device-biometric gate, mirroring check_in.php for the same reason as the
// mock-location block above: enforcing it on arrival only would let a colleague
// clock someone out.
if (TenantModel::requiresLocalBiometric($tenantId)
    && (int) ($input['local_biometric'] ?? 0) !== 1) {
    AttendanceSecurityModel::log(
        $tenantId,
        (int) $employee['id'],
        isset($employee['branch_id']) ? (int) $employee['branch_id'] : null,
        'no_local_biometric',
        'blocked',
        isset($input['latitude']) ? (float) $input['latitude'] : null,
        isset($input['longitude']) ? (float) $input['longitude'] : null
    );
    Response::fail(I18n::t('local_biometric_required'), 403, 'LOCAL_BIOMETRIC_REQUIRED');
}

// Face check-out. Verifying only the check-in would leave the method half
// enforced — a colleague could clock someone out. When face_selfie is the only
// self-service method the employee has, a check-out that doesn't carry a selfie
// is rejected outright, otherwise sending an empty body would bypass the face.
$methods = AttendanceMethodResolver::resolveForEmployee($employee, $tenantId);
$faceIsOnlySelfMethod = in_array('face_selfie', $methods, true)
    && !array_intersect(['qr_gps', 'gps_only'], $methods);
$declaredFace = ($input['method'] ?? null) === 'face_selfie';

if ($declaredFace || $faceIsOnlySelfMethod) {
    if (!$declaredFace) {
        Response::fail(I18n::t('face_required_for_checkout'), 400, 'FACE_REQUIRED');
    }

    $branchId = (int) ($employee['branch_id'] ?? 0);
    $branch = $branchId > 0 ? BranchModel::findById($branchId, $tenantId) : null;

    $verification = FaceMatchService::verify(
        $employee,
        $tenantId,
        $branch,
        'check_out',
        $input,
        isset($input['latitude']) ? (float) $input['latitude'] : null,
        isset($input['longitude']) ? (float) $input['longitude'] : null
    );

    if (!$verification['accepted']) {
        Response::fail(
            $verification['message'],
            403,
            'FACE_' . strtoupper($verification['result']),
            ['score' => $verification['score'], 'threshold' => $verification['threshold']]
        );
    }
}

// WiFi check-out. Same reasoning as the face path: verifying only the check-in
// would leave the constraint half enforced.
if (in_array('wifi_gps', $methods, true) && ($input['method'] ?? null) === 'wifi_gps') {
    $branchId = (int) ($employee['branch_id'] ?? 0);
    $branch = $branchId > 0 ? BranchModel::findById($branchId, $tenantId) : null;
    if ($branch !== null) {
        $network = NetworkVerifier::verify($branch, $input);
        if (!$network['accepted']) {
            Response::fail($network['message'], 403, 'WIFI_' . strtoupper($network['reason']));
        }
    }
}

// Same rule as check-in: capture the evidence before writing the punch, so a
// company that asked for a photo never gets attendance recorded without one.
$punchPhoto = null;
if ($isWeb && WebAccessPolicy::photoRequired($tenantId)) {
    $punchPhoto = PunchPhotoService::store($input['photo_base64'] ?? null, $tenantId, (int) $employee['id']);
    if ($punchPhoto === null) {
        Response::fail(I18n::t('web_photo_required'), 422, 'PHOTO_REQUIRED');
    }
}

AttendanceModel::checkOut($employee['id'], $tenantId);

$tenantToday = TenantClock::date($tenantId);
AttendanceModel::recordChannel($tenantId, (int) $employee['id'], $tenantToday, 'check_out', $origin, $punchPhoto);

$sessionEnded = false;
if ($isWeb) {
    $others = SharedDeviceDetector::otherEmployeesOnDevice(
        $tenantId,
        (string) ($auth['device_id'] ?? ''),
        (int) $employee['id'],
        $tenantToday
    );
    SharedDeviceDetector::flag(
        $tenantId,
        $tenantToday,
        (int) $employee['id'],
        $others,
        isset($employee['branch_id']) ? (int) $employee['branch_id'] : null
    );

    // The system ends the session, not the employee. A shared office computer
    // has to be left safe by default — relying on the person walking out to
    // remember a "log out" button is exactly how the next person inherits their
    // identity.
    WebSessionService::revokeAllForEmployee((int) $employee['id'], 'web_checked_out');
    $sessionEnded = true;
}

// Once the employee has left, any still-pending permission for today can no
// longer be acted on, so cancel it automatically.
$cancelledBreaks = BreakRequestModel::cancelPendingOnCheckOut($employee['id'], $tenantId);

Response::success([
    'message' => 'Check-out successful',
    // The tenant's wall clock, matching what was just stored.
    'time' => TenantClock::time($tenantId),
    'cancelled_breaks' => $cancelledBreaks,
    'session_ended' => $sessionEnded,
]);
