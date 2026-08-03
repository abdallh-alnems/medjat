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
$networkConstraint = 'none';
if ($branch) {
    $hasIpRule = Database::fetchOne(
        "SELECT 1 AS found
         FROM branch_networks
         WHERE branch_id = ? AND tenant_id = ? AND is_active = 1
           AND kind IN ('ip_v4', 'ip_cidr')
         LIMIT 1",
        [$branchId, $tenantId]
    );
    $networkConstraint = $hasIpRule ? 'ip' : 'none';
}

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
    // Sent so the interface never renders the device's own clock. A browser's
    // clock is user-editable with no permission prompt at all, which makes it a
    // weaker input than anything the mobile app has to deal with.
    'server_time' => $now->format('Y-m-d\TH:i:sP'),
]);
