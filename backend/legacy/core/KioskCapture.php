<?php

/**
 * Stores the capture behind a kiosk punch, as evidence.
 *
 * **Why an image is kept at all.** One-to-many identification means nobody
 * declared who they were — so when an employee says "that was not me", the
 * capture is the only thing that can settle it. With 1:1 verification the
 * employee's own session is corroborating evidence; here there is none.
 *
 * **Why it is aggressively downscaled.** These are not enrollment references.
 * `BiometricEnrollment` caps a reference photo at 2 MB, which is right for a
 * one-off image that a matcher will read. A kiosk produces one of these per
 * punch: a 40-person branch is roughly 1,700 images a month and ten branches an
 * order of magnitude more. At the enrollment cap that is tens of gigabytes a
 * month for pictures whose only job is to let a human recognise a face in a
 * dispute. 640px long edge at quality 70 does that in well under 100 KB.
 *
 * **Why it expires.** Evidence is useful for as long as a punch can be
 * disputed, which in practice is until the payroll cycle it belongs to closes.
 * Keeping it beyond that builds a permanent biometric archive of every worker's
 * face, several times a day, for no operational benefit.
 */
final class KioskCapture {
    private const MAX_INPUT_BYTES = 4 * 1024 * 1024;
    private const LONG_EDGE = 640;
    private const JPEG_QUALITY = 70;

    /** Fallback when a tenant's cycle cannot be resolved: ~2 payroll cycles. */
    private const DEFAULT_TTL_SECONDS = 60 * 24 * 3600;

    /**
     * Decodes, downscales, and writes the capture.
     *
     * Returns null rather than throwing when there is no usable image: a
     * missing photo must never be the reason an attendance record is refused.
     * The identification already happened; the picture is corroboration.
     */
    public static function store($imageBase64, int $tenantId, int $stationId): ?string {
        if (!is_string($imageBase64) || $imageBase64 === '') {
            return null;
        }

        try {
            $dir = __DIR__ . '/../uploads/kiosk/';
            if (!is_dir($dir) && !mkdir($dir, 0755, true) && !is_dir($dir)) {
                return null;
            }

            $data = base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $imageBase64), true);
            if ($data === false || $data === '' || strlen($data) > self::MAX_INPUT_BYTES) {
                return null;
            }

            // Confirm it really is an image before writing it under a .jpg name.
            $info = @getimagesizefromstring($data);
            if ($info === false) {
                return null;
            }

            $data = self::downscale($data) ?? $data;

            $name = sprintf(
                'kiosk_%d_%d_%d_%s.jpg',
                $tenantId,
                $stationId,
                time(),
                bin2hex(random_bytes(4))
            );

            if (file_put_contents($dir . $name, $data) === false) {
                return null;
            }

            return 'uploads/kiosk/' . $name;
        } catch (Throwable $e) {
            error_log('Kiosk capture store failed: ' . $e->getMessage());
            return null;
        }
    }

    /**
     * Retention window, in seconds, for a capture taken now.
     *
     * Resolved from the tenant's attendance cycle so the evidence outlives the
     * dispute window rather than a fixed number somebody guessed. Computed as a
     * seconds interval so the caller can hand it to
     * `DATE_ADD(NOW(), INTERVAL ? SECOND)` — expiries are computed in SQL here,
     * never in PHP, because PHP runs UTC and MySQL runs the tenant zone.
     */
    public static function ttlSeconds(int $tenantId): int {
        $tenant = TenantModel::findById($tenantId);
        $cycleStartDay = (int) ($tenant['cycle_start_day'] ?? 1);

        try {
            $now = TenantClock::now($tenantId);
            $cycleEnd = (clone $now)->setDate(
                (int) $now->format('Y'),
                (int) $now->format('n'),
                max(1, min(28, $cycleStartDay))
            );

            if ($cycleEnd <= $now) {
                $cycleEnd->modify('+1 month');
            }
            // One full cycle past the close of the current one, so a punch made
            // on the last day is still disputable for a whole cycle.
            $cycleEnd->modify('+1 month');

            $ttl = $cycleEnd->getTimestamp() - $now->getTimestamp();
            return $ttl > 0 ? $ttl : self::DEFAULT_TTL_SECONDS;
        } catch (Throwable $e) {
            return self::DEFAULT_TTL_SECONDS;
        }
    }

    /** Absolute path for a stored relative path, or null if it escapes uploads/. */
    public static function absolutePath(string $relativePath): ?string {
        if (!str_starts_with($relativePath, 'uploads/kiosk/') || str_contains($relativePath, '..')) {
            return null;
        }
        return __DIR__ . '/../' . $relativePath;
    }

    /**
     * Downscales to LONG_EDGE and re-encodes as JPEG.
     *
     * Returns null when GD is unavailable, so the caller falls back to the
     * original bytes: a missing extension should cost disk, not evidence.
     */
    private static function downscale(string $data): ?string {
        if (!function_exists('imagecreatefromstring')) {
            return null;
        }

        $src = @imagecreatefromstring($data);
        if ($src === false) {
            return null;
        }

        try {
            $w = imagesx($src);
            $h = imagesy($src);
            $longEdge = max($w, $h);

            if ($longEdge <= self::LONG_EDGE) {
                $dst = $src;
            } else {
                $scale = self::LONG_EDGE / $longEdge;
                $dst = imagescale($src, (int) round($w * $scale), (int) round($h * $scale));
                if ($dst === false) {
                    return null;
                }
            }

            ob_start();
            imagejpeg($dst, null, self::JPEG_QUALITY);
            $out = ob_get_clean();

            if ($dst !== $src) {
                imagedestroy($dst);
            }

            return $out !== false && $out !== '' ? $out : null;
        } finally {
            imagedestroy($src);
        }
    }
}
