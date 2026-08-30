<?php
/**
 * Retrieve the capture behind one kiosk attempt.
 *
 * The only endpoint in this feature that returns biometric imagery, and the
 * reason `kiosk_evidence` is a permission of its own rather than part of
 * `manage_attendance`. Reading scores is an operational task; looking at
 * photographs of colleagues is not, and the two should not travel together.
 *
 * With one-to-many identification nobody declared who they were, so this image
 * is the only thing that can settle "that was not me". It is also, for the same
 * reason, the most sensitive artefact the feature produces — which is why
 * every access is written to the audit log (FR-059) and why it expires.
 *
 * Input: recognition_log_id (required)
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'kiosk_evidence');

$logId = (int) ($auth['input']['recognition_log_id'] ?? 0);
Validator::required($logId, 'recognition_log_id');

$log = Database::fetchOne(
    "SELECT id, tenant_id, branch_id, employee_id, capture_path, capture_expires_at, created_at
       FROM station_recognition_logs
      WHERE id = ? AND tenant_id = ? LIMIT 1",
    [$logId, $tenantId]
);

if (!$log) {
    Response::notFound('Recognition attempt');
}

if (empty($log['capture_path'])) {
    // Either the retention window passed and the purge ran, or the attempt was
    // one whose capture is deliberately not kept (an unflagged failure). Saying
    // so plainly beats returning a broken image.
    Response::fail('This capture is no longer available', 410, 'kiosk_capture_expired', [
        'expired_at' => $log['capture_expires_at'],
    ]);
}

$absolute = KioskCapture::absolutePath((string) $log['capture_path']);
if ($absolute === null || !is_file($absolute)) {
    Response::fail('This capture is no longer available', 410, 'kiosk_capture_expired');
}

// Viewing another person's biometric evidence is itself an auditable act.
AuditLogModel::log(
    $tenantId,
    (int) $auth['admin_id'],
    'kiosk_capture_view',
    'station_recognition_log',
    $logId,
    [
        'employee_id' => $log['employee_id'],
        'branch_id'   => $log['branch_id'],
        'attempt_at'  => $log['created_at'],
    ]
);

Response::success([
    'recognition_log_id' => $logId,
    'employee_id'        => $log['employee_id'] !== null ? (int) $log['employee_id'] : null,
    'captured_at'        => $log['created_at'],
    'expires_at'         => $log['capture_expires_at'],
    // Inline rather than a static URL: uploads/ is not web-served, and a
    // guessable path would defeat the permission this endpoint enforces.
    'image_base64'       => 'data:image/jpeg;base64,' . base64_encode((string) file_get_contents($absolute)),
]);
