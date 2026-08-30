<?php

declare(strict_types=1);

namespace App\Services\Cron;

use App\Domain\Attendance\BranchQrChallenge;
use App\Domain\Kiosk\KioskCapture;
use App\Domain\Kiosk\RecognitionLog;
use App\Support\Value;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * Port of api/app/cron/purge_kiosk_captures.php.
 *
 * Deletes kiosk capture images once their retention window has passed.
 *
 * Kiosk identification is one-to-many — nobody declared who they were — so the
 * capture is the only thing that can settle a disputed punch. That is what
 * makes it worth keeping, and, for exactly the same reason, worth deleting:
 * without this the product accumulates a permanent photographic record of every
 * worker's face several times a day, indefinitely, for no operational benefit
 * once the payroll cycle it belongs to has closed. A forty-person branch
 * produces roughly 1,700 images a month.
 *
 * The file goes first, then the pointer. The log row survives — the scores on
 * it are what threshold tuning reads, and they carry no biometric content.
 * Doing it the other way round would orphan images on disk with nothing left
 * pointing at them.
 */
final class PurgeKioskCaptures
{
    /** One branch-year of captures can be tens of thousands of files. */
    private const BATCH = 500;

    private const MAX_PASSES = 20;

    /**
     * @return array{status: string, deleted: int, already_missing: int, failed: int, qr_challenges_purged: int}
     */
    public function execute(): array
    {
        $deleted = 0;
        $missing = 0;
        $failed = 0;

        for ($pass = 0; $pass < self::MAX_PASSES; $pass++) {
            $rows = RecognitionLog::expiredCaptures(self::BATCH);

            if ($rows === []) {
                break;
            }

            // A row whose delete fails keeps its path so the next *run* retries
            // it — which means the same batch comes back on the next pass here.
            // A pass that clears nothing can never make progress, so looping
            // again would only retry the same failures nineteen more times.
            $cleared = 0;

            foreach ($rows as $row) {
                $id = Value::int($row['id'] ?? null);
                $stored = Value::string($row['capture_path'] ?? null);
                $relative = KioskCapture::relativePath($stored);

                if ($relative === null) {
                    // A stored path that escapes uploads/kiosk/ is a bug worth
                    // leaving evidence of on disk: stop pointing at it, but do
                    // not delete whatever it points to.
                    Log::warning('Refusing to purge a suspicious capture path', ['path' => $stored]);
                    RecognitionLog::clearCapture($id);
                    $cleared++;
                    $failed++;

                    continue;
                }

                $disk = Storage::disk('uploads');

                if (! $disk->exists($relative)) {
                    RecognitionLog::clearCapture($id);
                    $cleared++;
                    $missing++;

                    continue;
                }

                if ($disk->delete($relative)) {
                    RecognitionLog::clearCapture($id);
                    $cleared++;
                    $deleted++;

                    continue;
                }

                // Leave the pointer intact so the next run retries. Clearing it
                // here would strand the file on disk permanently.
                Log::warning('Could not delete a kiosk capture', ['path' => $relative]);
                $failed++;
            }

            if ($cleared === 0) {
                break;
            }
        }

        return [
            'status' => 'ok',
            'deleted' => $deleted,
            'already_missing' => $missing,
            'failed' => $failed,
            'qr_challenges_purged' => $this->purgeQrChallenges(),
        ];
    }

    /**
     * Housekeeping that must never fail the purge above it — that one deletes
     * biometric material and is the reason this job runs at all.
     */
    private function purgeQrChallenges(): int
    {
        try {
            return BranchQrChallenge::purgeExpired();
        } catch (Throwable $e) {
            Log::warning('QR challenge purge failed', ['exception' => $e]);

            return 0;
        }
    }
}
