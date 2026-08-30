<?php

declare(strict_types=1);

namespace App\Domain\Biometric;

use App\Domain\Face\FaceEmbedding;
use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * What a company holds of somebody's face and fingerprint.
 *
 * The enrollment status is derived, never set directly: it is a statement of
 * which templates exist, so recording or clearing one recomputes it. Two
 * columns that could disagree about the same fact would eventually disagree.
 */
final class BiometricEnrollment
{
    public const TYPES = ['face', 'fingerprint', 'both'];

    /**
     * The fingerprint template is not stored.
     *
     * Fingerprints are matched by the terminal, which holds its own copy —
     * nothing on this side ever compares one, so keeping the template here
     * would be retaining an irrevocable biometric for no purpose. What is kept
     * is the fact and date of enrollment, which is all the status screens ask
     * for. Callers still send the template so the terminal-side flow is
     * unchanged and the endpoint can start storing it if matching ever moves
     * server-side.
     */
    public static function recordFingerprint(int $employeeId, int $tenantId): void
    {
        DB::update(
            'UPDATE employees SET'
            .' fingerprint_enrolled_at = NOW(),'
            .' biometric_enrollment_status = CASE'
            ."   WHEN face_embedding IS NOT NULL THEN 'both'"
            ."   ELSE 'fingerprint_only'"
            .' END'
            .' WHERE id = ? AND tenant_id = ?',
            [$employeeId, $tenantId],
        );
    }

    public static function clearFace(int $employeeId, int $tenantId): void
    {
        DB::update(
            'UPDATE employees SET'
            .' face_embedding = NULL,'
            .' face_photo_url = NULL,'
            .' face_model_version = NULL,'
            .' face_embedding_dim = NULL,'
            .' face_enrolled_at = NULL,'
            .' face_quality_score = NULL,'
            .' biometric_enrollment_status = CASE'
            ."   WHEN fingerprint_enrolled_at IS NOT NULL THEN 'fingerprint_only'"
            ."   ELSE 'not_enrolled'"
            .' END'
            .' WHERE id = ? AND tenant_id = ?',
            [$employeeId, $tenantId],
        );
    }

    public static function clearFingerprint(int $employeeId, int $tenantId): void
    {
        DB::update(
            'UPDATE employees SET'
            .' fingerprint_enrolled_at = NULL,'
            .' biometric_enrollment_status = CASE'
            ."   WHEN face_embedding IS NOT NULL THEN 'face_only'"
            ."   ELSE 'not_enrolled'"
            .' END'
            .' WHERE id = ? AND tenant_id = ?',
            [$employeeId, $tenantId],
        );
    }

    /**
     * @return array<string, mixed>|null
     */
    public static function status(int $employeeId, int $tenantId): ?array
    {
        $row = DB::table('employees')
            ->where('id', $employeeId)->where('tenant_id', $tenantId)
            ->first([
                'biometric_enrollment_status', 'face_enrolled_at', 'fingerprint_enrolled_at',
                'face_quality_score', 'face_photo_url', 'face_model_version', 'has_linked_account',
            ]);

        if ($row === null) {
            return null;
        }

        /** @var array<string, mixed> $status */
        $status = (array) $row;

        // An embedding from a retired model cannot be compared against the
        // current one. Surfacing it as needing re-enrollment is the difference
        // between a screen that says what to do and every check-in failing with
        // a mismatch nobody can explain.
        $status['needs_reenrollment'] = self::isStale(
            $status['face_enrolled_at'] ?? null,
            $status['face_model_version'] ?? null,
        );

        return $status;
    }

    /**
     * True when a face is enrolled but under a model that is no longer in use.
     *
     * A null version is *not* stale. Rows enrolled before the column existed
     * carry one, and the verifier accepts them — it only refuses a version that
     * is present and different. The original's two callers disagreed about
     * this: the employee's own screen matched the verifier, while HR's status
     * screen treated null as stale and so advised resetting enrollments that
     * were verifying people perfectly well. Whatever the verifier accepts is
     * the truth here; anything else sends people back through enrollment for
     * nothing.
     */
    public static function isStale(mixed $enrolledAt, mixed $modelVersion): bool
    {
        if ($enrolledAt === null || $modelVersion === null) {
            return false;
        }

        return Value::string($modelVersion) !== FaceEmbedding::MODEL_VERSION;
    }
}
