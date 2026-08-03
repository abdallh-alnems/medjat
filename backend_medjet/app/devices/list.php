<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

// Readable by whoever runs attendance day to day, and by whoever set the
// devices up — a role with one permission but not the other must not hit a
// 403 on a screen it can reach.
PermissionMiddleware::checkAny($auth, ['manage_attendance', 'manage_company_settings']);

$devices = AttendanceDeviceModel::listForTenant($tenantId);

// A terminal polls us every few seconds, so silence for five minutes means it
// is unplugged, off the network, or pointed somewhere else — the single most
// useful thing the screen can tell HR.
$onlineGrace = 300;

$devices = array_map(static function (array $d) use ($onlineGrace): array {
    $seen = $d['seconds_since_seen'];
    return [
        'id' => (int) $d['id'],
        'serial_number' => $d['serial_number'],
        'name' => $d['name'],
        'branch_id' => $d['branch_id'] !== null ? (int) $d['branch_id'] : null,
        'branch_name' => $d['branch_name'],
        'vendor' => $d['vendor'],
        'model' => $d['model'],
        'firmware' => $d['firmware'],
        'status' => $d['status'],
        'is_online' => $seen !== null && (int) $seen <= $onlineGrace,
        'seconds_since_seen' => $seen !== null ? (int) $seen : null,
        'last_seen_at' => $d['last_seen_at'],
        'last_punch_at' => $d['last_punch_at'],
        'direction_mode' => $d['direction_mode'],
        'min_interval_seconds' => (int) $d['min_interval_seconds'],
        'clock_offset_minutes' => (int) $d['clock_offset_minutes'],
        'keep_unmatched' => (bool) $d['keep_unmatched'],
        'debug_logging' => (bool) $d['debug_logging'],
        'linked_users' => (int) $d['linked_users'],
        'pending_users' => (int) $d['pending_users'],
        'punches_today' => (int) $d['punches_today'],
    ];
}, $devices);

Response::success(['devices' => $devices]);
