<?php
/**
 * A supervisor records arrival — or departure — for the people on site with them.
 *
 * THIS IS THE ONE PLACE AN EMPLOYEE CREDENTIAL ACTS FOR SOMEBODY ELSE.
 *
 * Thirty-three endpoints authenticate an employee; every other one of them
 * touches only that employee's own rows. That invariant is worth keeping, so
 * this file is separate from check_in.php rather than a branch inside it — a
 * reader who opens check_in.php should not have to notice that one path through
 * it writes other people's attendance.
 *
 * The exception is bounded by four things, all enforced here on the server:
 *
 *   1. The supervisor is whoever the token says. Never taken from the body.
 *   2. A target is only writable if their crew_supervisor_id IS the supervisor.
 *      There is no "supervisor" flag to get out of step with that.
 *   3. The batch is refused whole if any target fails (2) — see below.
 *   4. Every row records who recorded it.
 *
 * Input:  employee_ids[], latitude, longitude, is_check_out?, photo_base64?
 * Output: recorded[], skipped{}, count
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$supervisor = $auth['employee'];
$supervisorId = (int) $auth['employee_id'];
$input = $auth['input'];

$employeeIds = $input['employee_ids'] ?? null;
if (!is_array($employeeIds) || $employeeIds === []) {
    Response::fail('employee_ids is required', 422, 'CREW_EMPTY');
}

// A foreman's crew is tens of people, not thousands. The cap is here so a
// malformed or hostile body cannot turn one request into an unbounded write.
if (count($employeeIds) > 200) {
    Response::fail('Too many employees in one batch', 422, 'CREW_TOO_LARGE');
}

$isCheckOut = !empty($input['is_check_out']);

// --- authorisation -------------------------------------------------------
// Whole-batch refusal, not silent filtering. A supervisor who sends a name that
// is no longer theirs has a stale list, and quietly recording the other
// twenty-nine would leave them believing all thirty were marked. Telling them
// costs one retry; the silent version costs somebody a day's pay.
$outsiders = CrewModel::rejectOutsiders($supervisorId, $tenantId, $employeeIds);
if ($outsiders !== []) {
    foreach ($outsiders as $outsiderId) {
        AttendanceSecurityModel::log(
            $tenantId,
            $outsiderId,
            isset($supervisor['branch_id']) ? (int) $supervisor['branch_id'] : null,
            'crew_not_supervisor',
            'blocked',
            isset($input['latitude']) ? (float) $input['latitude'] : null,
            isset($input['longitude']) ? (float) $input['longitude'] : null
        );
    }

    Response::fail(
        I18n::t('crew_not_your_member'),
        403,
        'CREW_NOT_SUPERVISOR',
        ['employee_ids' => $outsiders]
    );
}

// --- the supervisor must be allowed to use this method at all ------------
$methods = AttendanceMethodResolver::resolveForEmployee($supervisor, $tenantId);
if (!in_array('crew_gps', $methods, true)) {
    Response::fail(I18n::t('crew_method_disabled'), 403, 'METHOD_NOT_ALLOWED');
}

// --- location ------------------------------------------------------------
// One fix, taken from the supervisor's phone, verified once and then written
// onto every row in the batch. That is the honest shape of the evidence: it
// says "the person who recorded this was at the site", not "each of these
// thirty people was individually located", and the column names say so too.
$latitude  = (float) ($input['latitude'] ?? 0);
$longitude = (float) ($input['longitude'] ?? 0);

if ($latitude == 0.0 && $longitude == 0.0) {
    Response::fail('Location is required', 400, 'LOCATION_REQUIRED');
}

$branchId = (int) ($supervisor['branch_id'] ?? 0);
if ($branchId <= 0) {
    Response::fail(I18n::t('crew_supervisor_no_branch'), 409, 'BRANCH_REQUIRED');
}

// Mirrors check_in.php: a spoofed location invalidates the geofence, so it is
// checked before it. Opt-in per company, Android only.
if (!empty($input['is_mock_location']) && TenantModel::rejectsMockLocation($tenantId)) {
    AttendanceSecurityModel::log(
        $tenantId, $supervisorId, $branchId, 'mock_location', 'blocked', $latitude, $longitude
    );
    Response::fail(I18n::t('mock_location_rejected'), 403, 'MOCK_LOCATION');
}

// Check-out is not geofenced, matching check_out.php: a company that disables a
// method mid-shift must still let an open day be closed, and a crew that has
// moved off site by knocking-off time should not be stranded clocked-in.
if (!$isCheckOut) {
    $gps = GpsService::validateCheckIn($latitude, $longitude, $branchId, $tenantId);
    if (!$gps['valid']) {
        AttendanceSecurityModel::log(
            $tenantId, $supervisorId, $branchId, 'gps_out_of_range', 'blocked', $latitude, $longitude
        );
        Response::fail($gps['message'], 400, $gps['reason'] ?? 'GPS_OUT_OF_RANGE');
    }
}

// --- evidence ------------------------------------------------------------
// Captured before anything is written, so a company that asked for a photograph
// never ends up with thirty rows and no picture.
$photoPath = null;
if (CrewModel::photoRequired($tenantId)) {
    $photoPath = PunchPhotoService::store($input['photo_base64'] ?? null, $tenantId, $supervisorId);
    if ($photoPath === null) {
        Response::fail(I18n::t('crew_photo_required'), 422, 'PHOTO_REQUIRED');
    }
}

// --- write ---------------------------------------------------------------
$result = $isCheckOut
    ? AttendanceModel::crewCheckOut($employeeIds, $tenantId, $supervisorId, $photoPath)
    : AttendanceModel::crewCheckIn($employeeIds, $branchId, $tenantId, $supervisorId, $latitude ?: null, $longitude ?: null, $photoPath);

AuditLogModel::log($tenantId, $auth['admin_id'], 'attendance.crew_' . ($isCheckOut ? 'check_out' : 'check_in'), null, null, [
    'supervisor_employee_id' => $supervisorId,
    'recorded' => count($result['recorded']),
    'skipped'  => count($result['skipped']),
]);

Response::success([
    'message'  => I18n::t($isCheckOut ? 'crew_check_out_done' : 'crew_check_in_done'),
    'count'    => count($result['recorded']),
    'recorded' => $result['recorded'],
    // Per-person reasons, so the app can show "28 recorded, 2 already marked"
    // instead of a bare success that hides what did not happen.
    'skipped'  => $result['skipped'],
    'time'     => TenantClock::time($tenantId),
]);
