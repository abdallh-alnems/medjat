<?php

declare(strict_types=1);

namespace App\Modules\Kiosk\Domain;

use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * The capture behind a kiosk punch, kept as evidence.
 *
 * Why an image is kept at all: one-to-many identification means nobody declared
 * who they were, so when an employee says "that was not me", the capture is the
 * only thing that can settle it. With one-to-one verification the employee's
 * own session is corroborating evidence; here there is none.
 *
 * Why it is aggressively downscaled: these are not enrollment references. A
 * kiosk produces one per punch — a 40-person branch is roughly 1,700 images a
 * month, and ten branches an order of magnitude more. At the enrollment size
 * cap that is tens of gigabytes a month for pictures whose only job is to let a
 * human recognise a face in a dispute.
 *
 * Why it expires: evidence is useful for as long as a punch can be disputed,
 * which in practice is until the payroll cycle it belongs to closes. Keeping it
 * beyond that builds a permanent biometric archive of every worker's face,
 * several times a day, for no operational benefit.
 */
final class KioskCapture
{
    private const MAX_INPUT_BYTES = 4 * 1024 * 1024;

    private const LONG_EDGE = 640;

    private const JPEG_QUALITY = 70;

    /** Fallback when a company's cycle cannot be resolved: about two cycles. */
    private const DEFAULT_TTL_SECONDS = 60 * 24 * 3600;

    /**
     * Decodes, downscales and writes the capture.
     *
     * Returns null rather than throwing when there is no usable image: a
     * missing photo must never be the reason an attendance record is refused.
     * The identification already happened; the picture is corroboration.
     */
    public static function store(mixed $imageBase64, int $tenantId, int $stationId): ?string
    {
        if (! is_string($imageBase64) || $imageBase64 === '') {
            return null;
        }

        try {
            $stripped = preg_replace('#^data:image/\w+;base64,#i', '', $imageBase64) ?? $imageBase64;
            $data = base64_decode($stripped, true);

            if ($data === false || $data === '' || strlen($data) > self::MAX_INPUT_BYTES) {
                return null;
            }

            // Confirm it really is an image before writing it under a .jpg name.
            if (@getimagesizefromstring($data) === false) {
                return null;
            }

            $data = self::downscale($data) ?? $data;

            $name = sprintf('kiosk_%d_%d_%d_%s.jpg', $tenantId, $stationId, time(), bin2hex(random_bytes(4)));
            $path = 'kiosk/'.$name;

            Storage::disk('uploads')->put($path, $data);

            return 'uploads/'.$path;
        } catch (Throwable $e) {
            Log::warning('Kiosk capture store failed', ['station_id' => $stationId, 'exception' => $e]);

            return null;
        }
    }

    /**
     * Retention window, in seconds, for a capture taken now.
     *
     * Resolved from the company's attendance cycle so the evidence outlives the
     * dispute window rather than a number somebody guessed. Returned as seconds
     * so the caller can hand it to a SQL interval — expiries are computed in
     * SQL here, never in PHP.
     */
    public static function ttlSeconds(int $tenantId): int
    {
        try {
            $configured = DB::table('tenants')->where('id', $tenantId)->value('cycle_start_day');
            $anchorDay = max(1, min(28, Value::int($configured, 1)));

            $now = TenantClock::now($tenantId);
            $cycleEnd = $now->setDate((int) $now->format('Y'), (int) $now->format('n'), $anchorDay);

            if ($cycleEnd <= $now) {
                $cycleEnd = $cycleEnd->modify('+1 month');
            }

            // One full cycle past the close of the current one, so a punch made
            // on the last day is still disputable for a whole cycle.
            $cycleEnd = $cycleEnd->modify('+1 month');

            $ttl = $cycleEnd->getTimestamp() - $now->getTimestamp();

            return $ttl > 0 ? $ttl : self::DEFAULT_TTL_SECONDS;
        } catch (Throwable) {
            return self::DEFAULT_TTL_SECONDS;
        }
    }

    /** The stored path relative to the uploads disk, or null if it escapes it. */
    public static function relativePath(string $storedPath): ?string
    {
        if (! str_starts_with($storedPath, 'uploads/kiosk/') || str_contains($storedPath, '..')) {
            return null;
        }

        return substr($storedPath, strlen('uploads/'));
    }

    /**
     * Downscales to the long edge and re-encodes as JPEG.
     *
     * Returns null when the image extension is unavailable, so the caller falls
     * back to the original bytes: a missing extension should cost disk, not
     * evidence.
     */
    private static function downscale(string $data): ?string
    {
        if (! function_exists('imagecreatefromstring')) {
            return null;
        }

        $source = @imagecreatefromstring($data);

        if ($source === false) {
            return null;
        }

        try {
            $width = imagesx($source);
            $height = imagesy($source);
            $longEdge = max($width, $height);

            if ($longEdge <= self::LONG_EDGE) {
                $target = $source;
            } else {
                $scale = self::LONG_EDGE / $longEdge;
                $scaled = imagescale($source, (int) round($width * $scale), (int) round($height * $scale));

                if ($scaled === false) {
                    return null;
                }

                $target = $scaled;
            }

            ob_start();
            imagejpeg($target, null, self::JPEG_QUALITY);
            $out = ob_get_clean();

            if ($target !== $source) {
                imagedestroy($target);
            }

            return is_string($out) && $out !== '' ? $out : null;
        } finally {
            imagedestroy($source);
        }
    }
}
