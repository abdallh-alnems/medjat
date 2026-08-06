<?php
// Deletes kiosk capture images whose retention window has passed.
//
// Kiosk identification is one-to-many: nobody declared who they were, so the
// capture is the only thing that can settle a disputed punch. That makes it
// worth keeping — and, for exactly the same reason, worth deleting. Without
// this job the product accumulates a permanent photographic record of every
// worker's face several times a day, indefinitely, for no operational benefit
// once the payroll cycle it belongs to has closed.
//
// The volume is not theoretical either: a 40-person branch produces roughly
// 1,700 images a month, ten branches an order of magnitude more.
//
// Deletes the FILE first, then nulls the path. The log ROW survives — the
// scores on it are what threshold tuning reads, and they carry no biometric
// content. Doing it the other way round would orphan images on disk with
// nothing left pointing at them.
//
// Recommended schedule: nightly, off-peak.
//
//   30 3 * * *  curl -s "https://<host>/app/cron/purge_kiosk_captures.php?key=<CRON_SECRET>"
//
// Idempotent — safe to run repeatedly.

require_once __DIR__ . '/../../config/bootstrap.php';
require_once __DIR__ . '/../../core/KioskCapture.php';

$key = $_GET['key'] ?? $_GET['cron_secret'] ?? '';
$expected = getenv('CRON_SECRET') ?: '';
if ($expected === '' || !hash_equals($expected, (string) $key)) {
    http_response_code(403);
    header('Content-Type: application/json');
    echo json_encode(['status' => 'forbidden']);
    exit;
}

$deleted = 0;
$missing = 0;
$failed  = 0;

// Batched: one branch-year of captures could be tens of thousands of files, and
// a cron that times out halfway leaves the ledger and the disk disagreeing.
// Each pass is self-contained, so the next run simply continues.
for ($pass = 0; $pass < 20; $pass++) {
    $rows = StationRecognitionLogModel::expiredCaptures(500);
    if (empty($rows)) {
        break;
    }

    // A row whose unlink fails keeps its capture_path so the next RUN retries
    // it. That means the same batch comes back on the next pass of this loop —
    // so a pass that clears nothing can never make progress, and looping again
    // would just retry the same failures nineteen more times.
    $clearedThisPass = 0;

    foreach ($rows as $row) {
        $absolute = KioskCapture::absolutePath((string) $row['capture_path']);

        if ($absolute === null) {
            // Path outside uploads/kiosk/ — refuse to unlink it, but stop
            // pointing at it. A stored path that escapes its directory is a bug
            // worth leaving evidence of on disk.
            error_log('purge_kiosk_captures: refusing suspicious path ' . $row['capture_path']);
            StationRecognitionLogModel::clearCapture((int) $row['id']);
            $clearedThisPass++;
            $failed++;
            continue;
        }

        if (!is_file($absolute)) {
            // Already gone. Clear the pointer so it stops being selected.
            StationRecognitionLogModel::clearCapture((int) $row['id']);
            $clearedThisPass++;
            $missing++;
            continue;
        }

        if (@unlink($absolute)) {
            StationRecognitionLogModel::clearCapture((int) $row['id']);
            $clearedThisPass++;
            $deleted++;
        } else {
            // Leave capture_path intact so the next run retries. Clearing it
            // here would strand the file on disk permanently.
            error_log('purge_kiosk_captures: could not unlink ' . $absolute);
            $failed++;
        }
    }

    if ($clearedThisPass === 0) {
        break;
    }
}

// Spent rotating QR challenges, cleaned up on the same nightly pass.
//
// This one is about volume, not privacy: a challenge row holds a random string
// and a timestamp. But a branch display asks for a code every 30 seconds all day,
// so one screen writes roughly 2,900 rows a day and ten screens close to a
// million a year, plus a use row per employee per punch. Without this the tables
// grow without bound to hold codes that stopped being valid ninety seconds after
// they were minted.
//
// branch_qr_uses goes with its parent via ON DELETE CASCADE, so deleting the
// challenge is the whole job. The day of slack the model keeps means a disputed
// punch from this morning can still be traced back to the code that produced it.
$qrPurged = 0;
try {
    $qrPurged = BranchQrChallengeModel::purgeExpired();
} catch (Throwable $e) {
    // Never let housekeeping fail the capture purge above it — that one deletes
    // biometric material and is the reason this job runs at all.
    error_log('purge_kiosk_captures: QR challenge purge failed: ' . $e->getMessage());
}

header('Content-Type: application/json');
echo json_encode([
    'status'  => 'ok',
    'deleted' => $deleted,
    'already_missing' => $missing,
    'failed'  => $failed,
    'qr_challenges_purged' => $qrPurged,
], JSON_UNESCAPED_UNICODE);
