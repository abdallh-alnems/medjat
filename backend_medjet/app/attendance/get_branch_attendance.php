<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_attendance');

$date = $_GET['date'] ?? date('Y-m-d');
$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;

if ($branchId) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

// "Today" resolved in the tenant timezone (fallback to server time).
$tenant = TenantModel::findById($tenantId);
$tz = $tenant['timezone'] ?? null;
try {
    $today = (new DateTime('now', $tz ? new DateTimeZone($tz) : null))->format('Y-m-d');
} catch (Exception $e) {
    $today = date('Y-m-d');
}

// For a completed (past) day, lazily backfill 'absent' rows for every no-show,
// honouring leaves, holidays, weekly-off and rotating rest days. Without this a
// past day with no check-in keeps showing "not arrived" instead of "absent".
// Idempotent (INSERT IGNORE), so it is safe to run on every view.
if ($date < $today) {
    AttendanceModel::markAbsentSmart($tenantId, $date, null);
}

$records = AttendanceModel::getByDate($tenantId, $date, $branchId);

// The stored photo paths never leave the server. A client asks for the image by
// attendance id through punch_photo.php, which re-checks permission; handing out
// the path would invite exactly the direct-URL fetching that uploads/ is now
// closed to.
$records = array_map(static function (array $r): array {
    $r['has_check_in_photo'] = !empty($r['check_in_photo']);
    $r['has_check_out_photo'] = !empty($r['check_out_photo']);
    unset($r['check_in_photo'], $r['check_out_photo']);
    // Advisory, never a verdict: the flag says one browser recorded attendance
    // for more than one employee today, which is information for a manager, not
    // a rejection (spec FR-020).
    $r['shared_device_flag'] = (bool) ($r['shared_device_flag'] ?? false);
    return $r;
}, $records);

Response::success([
    'records' => $records,
    'date' => $date,
]);
