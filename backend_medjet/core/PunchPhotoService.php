<?php

/**
 * Stores the image captured at a browser punch.
 *
 * This is evidence for a human, and nothing else. It is never scored, never
 * matched against an enrolled face, and never used to accept or reject a punch.
 * On the browser channel it is the only control that says anything about *who*
 * pressed the button — location and IP only say *where* — so it exists to be
 * looked at when a manager disputes a day, not to make a decision on its own.
 *
 * The transport mirrors face enrolment (base64 inside the JSON body) rather than
 * introducing multipart handling to a codebase that has none, and it inherits
 * that path's validation: decode, size cap, and confirm the bytes really are an
 * image before writing them under a .jpg name.
 */
final class PunchPhotoService {
    /** ~1.5 MB decoded. A check-in selfie needs far less; anything larger is a mistake or an attack. */
    private const MAX_PHOTO_BYTES = 1_500_000;

    private const SUBDIR = 'attendance';

    /**
     * @return string|null Relative path for storage on the attendance row, or
     *                     null when the payload was unusable. Callers MUST treat
     *                     null as a refusal when the company requires a photo —
     *                     recording the punch anyway would quietly remove a
     *                     control the company deliberately switched on.
     */
    public static function store(?string $imageBase64, int $tenantId, int $employeeId): ?string {
        if (!is_string($imageBase64) || $imageBase64 === '') {
            return null;
        }

        try {
            $dir = __DIR__ . '/../uploads/' . self::SUBDIR . '/';
            if (!is_dir($dir) && !mkdir($dir, 0755, true) && !is_dir($dir)) {
                error_log('PunchPhotoService: cannot create ' . $dir);
                return null;
            }

            $data = base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $imageBase64), true);
            if ($data === false || $data === '' || strlen($data) > self::MAX_PHOTO_BYTES) {
                return null;
            }

            // Confirm it really is an image before writing it under a .jpg name.
            // Without this the endpoint is an arbitrary-file-upload primitive
            // wearing an image extension.
            if (@getimagesizefromstring($data) === false) {
                return null;
            }

            $name = sprintf(
                'punch_%d_%d_%d_%s.jpg',
                $tenantId,
                $employeeId,
                time(),
                bin2hex(random_bytes(4))
            );

            if (file_put_contents($dir . $name, $data) === false) {
                error_log('PunchPhotoService: write failed for ' . $name);
                return null;
            }

            return self::SUBDIR . '/' . $name;
        } catch (Throwable $e) {
            error_log('PunchPhotoService: ' . $e->getMessage());
            return null;
        }
    }
}
