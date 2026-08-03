<?php
require_once __DIR__ . '/../../config/bootstrap.php';

/**
 * Imports a punch export from any fingerprint terminal, by file.
 *
 * This is the vendor-neutral way in. `device/iclock.php` speaks ZKTeco's ADMS
 * dialect and only devices that talk it can use it; every terminal ever made,
 * of any brand, can write a file to a USB stick. That covers the two customers
 * the push endpoint cannot reach at all: the one whose device is a brand we
 * have no adapter for, and the one whose device is not on a network.
 *
 * Both routes converge immediately: parsed rows are stored in `device_punches`
 * and handed to DevicePunchIngestor::apply(), the same code that judges a live
 * punch. Employee linking, direction, clock sanity and repeat-tap suppression
 * are therefore identical whether a punch arrived over the wire or on a stick.
 *
 * Rows whose device user id is not yet linked to an employee land as
 * `unmatched` — not an error. Linking them in the device-users screen replays
 * them into attendance automatically (see app/devices/link_user.php).
 */

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_attendance');

/** Uploads are capped well below a realistic export: a year of punches for 500 staff is ~5 MB. */
const IMPORT_MAX_BYTES = 8388608;
const IMPORT_MAX_ROWS = 20000;

// ── input ───────────────────────────────────────────────────────────────
// The file may arrive as a multipart upload or as pasted text, because the
// same endpoint serves the web page and the mobile app.
$input = $_POST ?: ($auth['input'] ?? []);

$deviceId = isset($input['device_id']) ? (int) $input['device_id'] : 0;
$branchId = isset($input['branch_id']) ? (int) $input['branch_id'] : 0;
$preview = filter_var($input['preview'] ?? false, FILTER_VALIDATE_BOOLEAN);

$raw = null;
if (isset($_FILES['file'])) {
    $file = $_FILES['file'];
    if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
        Response::fail('File upload failed', 400, 'UPLOAD_FAILED');
    }
    if (($file['size'] ?? 0) > IMPORT_MAX_BYTES) {
        Response::fail('File is too large', 413, 'FILE_TOO_LARGE');
    }
    $raw = file_get_contents($file['tmp_name']);
} elseif (isset($input['csv_text']) && trim((string) $input['csv_text']) !== '') {
    $raw = (string) $input['csv_text'];
    if (strlen($raw) > IMPORT_MAX_BYTES) {
        Response::fail('File is too large', 413, 'FILE_TOO_LARGE');
    }
}

if ($raw === null || trim($raw) === '') {
    Response::fail('A CSV file is required', 422, 'FILE_REQUIRED');
}

// ── where the punches belong ────────────────────────────────────────────
// Either an already-registered terminal (the customer has one, it is just
// offline) or a branch, in which case a file-import device stands in for it so
// that every punch still has a device row to hang off.
if ($deviceId > 0) {
    $device = AttendanceDeviceModel::findById($deviceId, $tenantId);
    if (!$device) {
        Response::notFound('Device');
    }
    if ($device['branch_id'] === null) {
        Response::fail('This device is not assigned to a branch', 422, 'DEVICE_WITHOUT_BRANCH');
    }
} else {
    if ($branchId <= 0) {
        Response::fail('Choose a branch or a device for the import', 422, 'BRANCH_REQUIRED');
    }
    $branch = BranchModel::findById($branchId, $tenantId);
    if (!$branch) {
        Response::notFound('Branch');
    }
    $device = AttendanceDeviceModel::ensureFileImportDevice($tenantId, $branchId, $auth['admin_id']);
}

// ── parse ───────────────────────────────────────────────────────────────
$parsed = PunchCsvParser::parse($raw);

if ($parsed['rows'] === [] && $parsed['errors'] === []) {
    Response::fail('The file has no rows', 422, 'FILE_EMPTY');
}
if (count($parsed['rows']) > IMPORT_MAX_ROWS) {
    Response::fail('The file has too many rows; split it into smaller files', 413, 'TOO_MANY_ROWS');
}

// Nothing readable at all almost always means the wrong column was taken for
// the user id or the timestamp — say so instead of reporting "0 imported".
if ($parsed['rows'] === []) {
    Response::fail(
        'No row in this file could be read. Check that it has an employee/user id column and a date column.',
        422,
        'NO_READABLE_ROWS',
        ['errors' => array_slice($parsed['errors'], 0, 20), 'error_count' => count($parsed['errors'])]
    );
}

$sample = array_map(
    static fn(array $r): array => [
        'line' => $r['line'],
        'device_user_id' => $r['user_id'],
        'punched_at' => $r['punched_at'],
    ],
    array_slice($parsed['rows'], 0, 10)
);

// A preview commits nothing. Bulk imports are the one place a mistake is
// expensive and invisible, so the admin gets to see what was understood —
// especially the day/month reading — before any of it is written.
if ($preview) {
    Response::success([
        'preview' => true,
        'device_id' => (int) $device['id'],
        'branch_id' => (int) $device['branch_id'],
        'readable_rows' => count($parsed['rows']),
        'unreadable_rows' => count($parsed['errors']),
        'first_punch' => $parsed['rows'][0]['punched_at'],
        'last_punch' => $parsed['rows'][count($parsed['rows']) - 1]['punched_at'],
        'distinct_users' => count(array_unique(array_column($parsed['rows'], 'user_id'))),
        'date_order' => $parsed['date_order'],
        'date_order_ambiguous' => $parsed['date_order_ambiguous'],
        'had_header' => $parsed['had_header'],
        'sample' => $sample,
        'errors' => array_slice($parsed['errors'], 0, 20),
    ]);
}

// ── store and apply ─────────────────────────────────────────────────────
$now = DevicePunchIngestor::now();
$results = ['applied' => 0, 'duplicate' => 0, 'ignored' => 0, 'failed' => 0, 'unmatched' => 0];
$alreadyImported = 0;
$newUsers = [];

foreach ($parsed['rows'] as $row) {
    $stored = DevicePunchModel::record(
        (int) $device['id'],
        $tenantId,
        $row['user_id'],
        $row['punched_at'],
        $row['status'],
        $row['verify'],
        null,
        $row['raw']
    );

    // Re-importing the same export — which happens constantly, because the
    // obvious way to catch up is to export everything again — must not create
    // a second attendance row for the same tap.
    if ($stored['duplicate']) {
        $alreadyImported++;
        continue;
    }

    if (!isset($newUsers[$row['user_id']])) {
        DeviceUserModel::ensure((int) $device['id'], $tenantId, $row['user_id']);
        $newUsers[$row['user_id']] = true;
    }
    DeviceUserModel::touchPunch((int) $device['id'], $row['user_id'], $row['punched_at']);

    $state = DevicePunchIngestor::apply($device, [
        'id' => $stored['id'],
        'device_user_id' => $row['user_id'],
        'punched_at' => $row['punched_at'],
        'status_code' => $row['status'],
        'verify_mode' => $row['verify'],
    ], $now);

    if (isset($results[$state])) {
        $results[$state]++;
    }
}

AttendanceDeviceModel::touchPunch(
    (int) $device['id'],
    $parsed['rows'][count($parsed['rows']) - 1]['punched_at']
);

AuditLogModel::log($tenantId, $auth['admin_id'], 'device.import_punches', 'device', (int) $device['id'], [
    'rows' => count($parsed['rows']),
    'applied' => $results['applied'],
    'unmatched' => $results['unmatched'],
    'already_imported' => $alreadyImported,
]);

// `unmatched` is the expected outcome of a first import, not a failure: those
// device user ids have never been linked to an employee. Report it separately
// so the screen can send the admin to the linking page instead of showing a
// count of things that "went wrong".
$unlinked = DeviceUserModel::listForDevice((int) $device['id'], $tenantId, 'unlinked');

Response::success([
    'preview' => false,
    'device_id' => (int) $device['id'],
    'branch_id' => (int) $device['branch_id'],
    'read_rows' => count($parsed['rows']),
    'unreadable_rows' => count($parsed['errors']),
    'already_imported' => $alreadyImported,
    'results' => $results,
    'date_order' => $parsed['date_order'],
    'date_order_ambiguous' => $parsed['date_order_ambiguous'],
    'unlinked_users' => count($unlinked),
    'errors' => array_slice($parsed['errors'], 0, 20),
]);
