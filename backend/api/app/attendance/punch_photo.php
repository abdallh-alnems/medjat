<?php
/**
 * Serves the image captured at a browser punch, to a caller who is allowed to
 * review that employee's attendance and to nobody else.
 *
 * The images live under uploads/, which nginx refuses outright (see
 * deploy/nginx/README.md) — this endpoint is the only way to them. Photographs
 * of employees' faces are exactly the kind of file that must not be reachable by
 * guessing a filename, and an authenticated route is what makes "who may look at
 * this" a question the system can answer.
 *
 * GET ?attendance_id=<id>&which=check_in|check_out
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_attendance');

$attendanceId = (int) ($_GET['attendance_id'] ?? 0);
Validator::required($attendanceId, 'attendance_id');

$which = $_GET['which'] ?? 'check_in';
if (!in_array($which, ['check_in', 'check_out'], true)) {
    Response::fail('which must be check_in or check_out', 422, 'invalid_which');
}

$row = Database::fetchOne(
    "SELECT a.check_in_photo, a.check_out_photo, a.branch_id, e.branch_id AS employee_branch_id
     FROM attendance a
     JOIN employees e ON e.id = a.employee_id AND e.tenant_id = a.tenant_id
     WHERE a.id = ? AND a.tenant_id = ?
     LIMIT 1",
    [$attendanceId, $tenantId]
);

if (!$row) {
    Response::notFound('Attendance');
}

// A branch-scoped reviewer may only see the branches they were given. Checked
// against the punch's branch, falling back to the employee's, so a punch
// recorded at another site is judged by where it happened.
$branchId = (int) ($row['branch_id'] ?: $row['employee_branch_id'] ?: 0);
if ($branchId > 0) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

$stored = $which === 'check_in' ? $row['check_in_photo'] : $row['check_out_photo'];
if (!is_string($stored) || $stored === '') {
    Response::notFound('Photo');
}

$path = PunchPhotoService::absolutePathFor($stored);
if ($path === null) {
    Response::notFound('Photo');
}

header('Content-Type: image/jpeg');
header('Content-Length: ' . filesize($path));
header('Content-Disposition: inline; filename="punch_' . $attendanceId . '_' . $which . '.jpg"');
header('X-Content-Type-Options: nosniff');
// Private and uncached: this is an employee's photograph, not an asset. It must
// not sit in a shared proxy or on the Cloudflare edge, which is precisely how
// the payslip leak survived the origin being fixed.
header('Cache-Control: private, no-store, max-age=0');
readfile($path);
exit;
