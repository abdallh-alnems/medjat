<?php
/**
 * The kiosk fleet, for the management app.
 *
 * `below_min_version` is the field that matters most here and the reason this
 * endpoint reports each tablet's version at all. Raising
 * `permedjat_kiosk_min_version` takes every outdated tablet OFFLINE, and unlike
 * the store apps there is nowhere to send them to update — somebody has to walk
 * to each branch. So the blast radius has to be answerable *before* the minimum
 * changes, not discovered afterwards from support calls.
 *
 * Input: branch_id (optional; omit for every branch in the tenant)
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'kiosk_devices');

$branchId = isset($auth['input']['branch_id']) && $auth['input']['branch_id'] !== ''
    ? (int) $auth['input']['branch_id']
    : null;

if ($branchId !== null && !BranchModel::findById($branchId, $tenantId)) {
    Response::notFound('Branch');
}

$gate = RemoteConfigService::gateFor('permedjat_kiosk');
$minVersion = $gate['min_version'] ?? '0.0.0';

$stations = array_map(static function (array $s) use ($minVersion): array {
    $version = $s['app_version'] ?? null;

    return [
        'id'     => (int) $s['id'],
        'name'   => $s['name'],
        'status' => $s['status'],
        'branch' => [
            'id'   => (int) $s['branch_id'],
            'name' => $s['branch_name'],
        ],
        'device_model' => $s['device_model'],
        'app_version'  => $version,
        // Null version = paired before it ever reported one; treated as current
        // rather than as broken, so a fresh pairing is not flagged.
        'below_min_version' => $version !== null && RemoteConfigService::isBelow($version, $minVersion),
        'last_seen_at'  => $s['last_seen_at'],
        'is_offline'    => (bool) $s['is_offline'],
        'punch_count'   => (int) $s['punch_count'],
        'last_punch_at' => $s['last_punch_at'],
        'paired_at'     => $s['paired_at'],
        'revoked_at'    => $s['revoked_at'],
    ];
}, KioskStationModel::listForTenant($tenantId, $branchId));

$wouldBlock = count(array_filter(
    $stations,
    static fn(array $s): bool => $s['below_min_version'] && $s['status'] === 'active'
));

// ---- Roster size, and the ceiling nobody can design away --------------------
// One-to-many identification gets harder with every enrolled face: false-accept
// risk compounds across the roster, so there is a branch size beyond which no
// threshold can hold the target mis-attribution rate. This does not block
// anything — refusing to serve a branch that grew would be worse than telling
// its administrator that face-only identification has reached its limit and the
// personal code should carry more of the load.
$rosterSql = "SELECT s.branch_id, b.name AS branch_name,
                     COUNT(e.id) AS enrolled
                FROM attendance_stations s
                JOIN branches b ON b.id = s.branch_id
           LEFT JOIN employees e
                  ON e.branch_id = s.branch_id
                 AND e.tenant_id = s.tenant_id
                 AND e.status <> 'terminated'
                 AND e.face_embedding IS NOT NULL
               WHERE s.tenant_id = ? AND s.status = 'active'";
$rosterParams = [$tenantId];

if ($branchId !== null) {
    $rosterSql .= " AND s.branch_id = ?";
    $rosterParams[] = $branchId;
}

$rosters = array_map(
    static fn(array $r): array => [
        'branch_id'    => (int) $r['branch_id'],
        'branch_name'  => $r['branch_name'],
        'enrolled'     => (int) $r['enrolled'],
        'warn_above'   => KioskIdentifier::ROSTER_WARN_ABOVE,
        'over_ceiling' => (int) $r['enrolled'] > KioskIdentifier::ROSTER_WARN_ABOVE,
    ],
    Database::fetchAll($rosterSql . " GROUP BY s.branch_id, b.name", $rosterParams)
);

Response::success([
    'stations'   => $stations,
    'min_version' => $minVersion,
    // Surfaced explicitly so the management screen can warn before anybody
    // raises the minimum version.
    'would_block_count' => $wouldBlock,
    'version_gate_stale' => (bool) ($gate['stale'] ?? false),
    'rosters' => $rosters,
]);
