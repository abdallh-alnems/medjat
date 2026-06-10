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

Response::success([
    'records' => $records,
    'date' => $date,
]);
