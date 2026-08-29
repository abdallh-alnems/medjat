<?php

/**
 * Shared helpers for face enrollment, used by both the HR-driven endpoint
 * (app/biometric/enroll_face.php) and employee self-enrollment
 * (app/biometric/enroll_self.php).
 */
final class BiometricEnrollment {
    /** Enrolled reference photos are small; anything larger is not a selfie. */
    private const MAX_PHOTO_BYTES = 2 * 1024 * 1024;

    /** Quality below this is rejected — a blurry enrollment poisons every later match. */
    public const MIN_QUALITY_SCORE = 0.5;

    /**
     * Decodes and stores the enrollment reference photo.
     *
     * Returns null (rather than throwing) when there is no usable image: the
     * embedding is what matters, the photo is for HR audit.
     */
    public static function storeReferencePhoto($imageBase64, int $tenantId, int $employeeId): ?string {
        if (!is_string($imageBase64) || $imageBase64 === '') {
            return null;
        }

        try {
            $dir = __DIR__ . '/../uploads/faces/';
            if (!is_dir($dir) && !mkdir($dir, 0755, true) && !is_dir($dir)) {
                return null;
            }

            $data = base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $imageBase64), true);
            if ($data === false || $data === '' || strlen($data) > self::MAX_PHOTO_BYTES) {
                return null;
            }

            // Confirm it really is an image before writing it under a .jpg name.
            if (@getimagesizefromstring($data) === false) {
                return null;
            }

            $name = 'face_' . $tenantId . '_' . $employeeId . '_' . time() . '_' . bin2hex(random_bytes(4)) . '.jpg';
            if (file_put_contents($dir . $name, $data) === false) {
                return null;
            }

            return 'uploads/faces/' . $name;
        } catch (Exception $e) {
            error_log('Face reference photo failed: ' . $e->getMessage());
            return null;
        }
    }
}
