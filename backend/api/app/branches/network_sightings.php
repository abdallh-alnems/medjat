<?php
/**
 * Networks seen at a branch during the learning window, for the approval
 * screen.
 *
 * The `coverage` figure is the point of this endpoint: it answers "if I approve
 * exactly these networks and switch to enforcing, what share of last week's
 * check-ins would still pass?" — BEFORE the admin flips the switch, instead of
 * finding out from a queue of complaints the next morning.
 *
 * Input:  branch_id, days (optional)
 * Output: mode, networks[], coverage summary
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

$days = (int) ($input['days'] ?? NetworkVerifier::SIGHTING_WINDOW_DAYS);
$rows = BranchNetworkModel::sightingsFor($branchId, $tenantId, $days);
$total = BranchNetworkModel::sightingTotal($branchId, $tenantId, $days);

$approvedSightings = 0;
$networks = array_map(static function ($r) use (&$approvedSightings) {
    $sightings = (int) $r['sightings'];
    $inside = (int) $r['inside_count'];
    $isApproved = (bool) $r['is_approved'];
    if ($isApproved) {
        $approvedSightings += $sightings;
    }

    return [
        'bssid' => $r['bssid'],
        'ssid' => $r['ssid'],
        'sightings' => $sightings,
        'inside_count' => $inside,
        'outside_count' => $sightings - $inside,
        // A network only ever seen from outside the geofence is almost always
        // an employee's home router, caught during the learning week.
        'all_inside' => $inside === $sightings,
        'all_outside' => $inside === 0,
        'employee_count' => (int) $r['employee_count'],
        'last_seen' => $r['last_seen'],
        'is_approved' => $isApproved,
    ];
}, $rows);

Response::success([
    'branch_id' => $branchId,
    'wifi_mode' => $branch['wifi_mode'],
    'wifi_match' => $branch['wifi_match'] ?? 'bssid',
    'days' => $days,
    'total_sightings' => $total,
    // Share of sightings already covered by the approved list. The UI recomputes
    // this live as the admin ticks boxes; this is the current-state baseline.
    'coverage_percent' => $total > 0 ? round(($approvedSightings / $total) * 100, 1) : 0.0,
    'networks' => $networks,
]);
