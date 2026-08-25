<?php

/**
 * What the browser attendance page needs to render truthfully.
 *
 * It reports the employee's state for **today across every channel**, not just
 * the browser. An employee who checked in on their phone this morning must see
 * "checked in" here, or the page would cheerfully offer them a second check-in
 * for the same day.
 *
 * Contract: specs/004-web-attendance-checkin/contracts/attendance-web.md
 */

require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());

$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];
$employeeId = (int) $employee['id'];

// Bounds one employee's traffic; the per-IP limit is a shared bucket behind
// the web proxy and cannot do this. See WebSessionService for why.
WebSessionService::enforcePerEmployeeLimit($auth);

$access = WebAccessPolicy::check($employee, $tenantId);
if (!$access['allowed']) {
    WebAccessPolicy::refuse($tenantId, $employeeId, $access['reason'], null);
}

$now = TenantClock::now($tenantId);
$today = $now->format('Y-m-d');

$row = Database::fetchOne(
    "SELECT check_in_time, check_out_time, check_in_origin, check_out_origin, branch_id
     FROM attendance
     WHERE employee_id = ? AND tenant_id = ? AND date = ?
     LIMIT 1",
    [$employeeId, $tenantId, $today]
);

if (!$row || empty($row['check_in_time'])) {
    $state = 'not_checked_in';
} elseif (empty($row['check_out_time'])) {
    $state = 'checked_in';
} else {
    $state = 'checked_out';
}

$branchId = (int) ($row['branch_id'] ?? $employee['branch_id'] ?? 0);
$branch = $branchId > 0 ? BranchModel::findById($branchId, $tenantId) : null;

// A browser has no API for the wireless access point it is joined to, so only
// the IP-shaped rows are reachable from this channel. A branch whose approved
// networks are all BSSIDs therefore has *no* network control here, and the UI is
// told so rather than being allowed to imply one exists.
//
// Answered by the same helper the punch path calls, not by a second query
// written here. The two used to disagree — this endpoint reported 'ip' off the
// mere existence of a row while check_in.php applied nothing at all — and the
// page spent that whole time claiming a control that was not there.
$networkConstraint = $branch ? NetworkVerifier::browserConstraint($branch) : 'none';

// Whether this employee can punch from a browser AT ALL, which is not the same
// question as whether the channel is open to them.
//
// The page sends no `method`, so check_in.php resolves the punch as 'gps_only'.
// An employee whose methods do not include it is refused at the moment they
// press the button — and with a message picked for a phone that can scan, which
// is the one thing this page cannot do. Better to say so up front than to hand
// someone a button that is guaranteed to fail.
$methods = AttendanceMethodResolver::resolveForEmployee($employee, $tenantId);
$canPunch = in_array('gps_only', $methods, true);

Response::success([
    'state' => $state,
    'check_in_at' => $row['check_in_time'] ?? null,
    'check_out_at' => $row['check_out_time'] ?? null,
    'check_in_origin' => $row['check_in_origin'] ?? null,
    'check_out_origin' => $row['check_out_origin'] ?? null,
    'branch' => $branch ? [
        'id' => (int) $branch['id'],
        'name' => $branch['name'],
        'latitude' => $branch['latitude'] !== null ? (float) $branch['latitude'] : null,
        'longitude' => $branch['longitude'] !== null ? (float) $branch['longitude'] : null,
        'gps_radius_meters' => (int) ($branch['gps_radius_meters'] ?? GpsService::DEFAULT_GPS_RADIUS),
    ] : null,
    'photo_required' => WebAccessPolicy::photoRequired($tenantId),
    'network_constraint' => $networkConstraint,
    'can_punch' => $canPunch,
    // A code, not a sentence, so each client localizes it. Null when it can.
    'blocked_reason' => $canPunch ? null : 'gps_only_not_enabled',
    // Sent so the interface never renders the device's own clock. A browser's
    // clock is user-editable with no permission prompt at all, which makes it a
    // weaker input than anything the mobile app has to deal with.
    'server_time' => $now->format('Y-m-d\TH:i:sP'),
]);
