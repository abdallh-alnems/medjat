<?php

declare(strict_types=1);

namespace App\Shared\Face;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * Recording somebody's face so a later capture can be matched against it.
 *
 * One enrollment path, whichever surface performed it: HR from the management
 * app, an employee enrolling themselves, or a supervisor at a kiosk. They write
 * the same columns, so an enrollment captured at a tablet *is* the enrollment a
 * selfie punch matches against — not a parallel one.
 */
final class FaceEnrollment
{
    /** Enrolled reference photos are small; anything larger is not a selfie. */
    private const MAX_PHOTO_BYTES = 2 * 1024 * 1024;

    /**
     * Quality below this is refused.
     *
     * A blurry enrollment does not fail loudly — it quietly stops matching its
     * owner and starts resembling other people, which is worse than no
     * enrollment at all.
     */
    public const MIN_QUALITY_SCORE = 0.5;

    /**
     * Decodes and stores the reference photo.
     *
     * Returns null rather than throwing when there is no usable image: the
     * embedding is what matching needs, and the photo is for a human reviewing
     * the record later.
     */
    public static function storeReferencePhoto(mixed $imageBase64, int $tenantId, int $employeeId): ?string
    {
        if (! is_string($imageBase64) || $imageBase64 === '') {
            return null;
        }

        try {
            $stripped = preg_replace('#^data:image/\w+;base64,#i', '', $imageBase64) ?? $imageBase64;
            $data = base64_decode($stripped, true);

            if ($data === false || $data === '' || strlen($data) > self::MAX_PHOTO_BYTES) {
                return null;
            }

            // Confirm it really is an image before writing it under a .jpg name.
            if (@getimagesizefromstring($data) === false) {
                return null;
            }

            $name = sprintf('face_%d_%d_%d_%s.jpg', $tenantId, $employeeId, time(), bin2hex(random_bytes(4)));
            Storage::disk('uploads')->put('faces/'.$name, $data);

            return 'uploads/faces/'.$name;
        } catch (Throwable $e) {
            Log::warning('Face reference photo failed', ['employee_id' => $employeeId, 'exception' => $e]);

            return null;
        }
    }

    /**
     * @param  list<float>  $embedding
     */
    public static function record(
        int $employeeId,
        int $tenantId,
        array $embedding,
        ?string $photoUrl,
        float $qualityScore,
        string $modelVersion,
    ): void {
        DB::update(
            'UPDATE employees SET'
            .' face_embedding = ?,'
            // Keeps an existing reference image when a re-enrollment arrives
            // without one.
            .' face_photo_url = COALESCE(?, face_photo_url),'
            .' face_model_version = ?,'
            .' face_embedding_dim = ?,'
            .' face_enrolled_at = NOW(),'
            .' face_quality_score = ?,'
            .' biometric_enrollment_status = CASE'
            ."   WHEN fingerprint_enrolled_at IS NOT NULL THEN 'both'"
            ."   ELSE 'face_only'"
            .' END'
            .' WHERE id = ? AND tenant_id = ?',
            [
                json_encode($embedding),
                $photoUrl,
                $modelVersion,
                count($embedding),
                $qualityScore,
                $employeeId,
                $tenantId,
            ],
        );
    }
}
