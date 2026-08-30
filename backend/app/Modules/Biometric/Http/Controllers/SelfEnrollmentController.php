<?php

declare(strict_types=1);

namespace App\Modules\Biometric\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Branch;
use App\Models\Employee;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Biometric\Domain\BiometricEnrollment;
use App\Shared\Face\FaceChallenge;
use App\Shared\Face\FaceEmbedding;
use App\Shared\Face\FaceEnrollment;
use App\Shared\Face\FaceMatcher;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Ports of api/app/biometric/{enroll_self,my_status}.php.
 *
 * An employee enrolling their own face from the employee app. Self-service
 * rather than HR-driven because only the employee app ships the embedding
 * model, and walking every employee past an HR device does not scale.
 *
 * HR keeps control two ways: the reference photo shows on the employee profile,
 * and enrollment is one-time — changing it needs an HR reset.
 */
final class SelfEnrollmentController
{
    public function __construct(private readonly FaceMatcher $faces) {}

    public function enroll(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $this->assertNotAlreadyEnrolled($employee);

        $settings = $this->faces->settingsFor($this->branch($employee, $tenantId), $tenantId);

        // Enrollment clears the same liveness bar as a check-in. Without it
        // somebody could enrol a printed photo, and every later match would be
        // against that photo — the one failure that verifies cleanly forever.
        $challenge = FaceChallenge::consume(
            Value::string($request->input('face_nonce')), $tenantId, $employee->id, 'enroll',
        );

        if ($challenge === null) {
            throw new ApiFailure(__('messages.face_challenge_expired'), 400, 'FACE_INVALID_CHALLENGE');
        }

        if ($settings['liveness_required'] && ! $request->boolean('liveness_passed')) {
            throw new ApiFailure(__('messages.face_liveness_failed'), 403, 'FACE_LIVENESS_FAILED');
        }

        $vector = FaceEmbedding::parse($request->input('embedding'));

        if ($vector === null) {
            throw new ApiFailure(__('messages.face_capture_failed'), 422, 'FACE_BAD_EMBEDDING');
        }

        $quality = Value::float($request->input('quality_score'));

        // A blurry enrollment does not fail loudly. It quietly stops matching
        // its owner and starts resembling other people, which is worse than no
        // enrollment at all.
        if ($quality < FaceEnrollment::MIN_QUALITY_SCORE) {
            throw new ApiFailure(__('messages.face_quality_too_low'), 422, 'FACE_QUALITY_TOO_LOW');
        }

        $photoUrl = FaceEnrollment::storeReferencePhoto(
            $request->input('image_base64'), $tenantId, $employee->id,
        );

        FaceEnrollment::record(
            $employee->id, $tenantId, $vector, $photoUrl, $quality, FaceEmbedding::MODEL_VERSION,
        );

        AuditLog::record($tenantId, null, 'biometric.self_enroll_face', 'employee', $employee->id);

        return ApiResponse::success([
            'status' => 'face_enrolled',
            // The tenant's clock, not the server's: PHP runs UTC here and the
            // app shows this to somebody who knows what time it is locally.
            'enrolled_at' => TenantClock::now($tenantId)->format('Y-m-d H:i:s'),
            'model_version' => FaceEmbedding::MODEL_VERSION,
        ], 201);
    }

    /**
     * Whether to send the employee to enrollment or straight to the camera.
     */
    public function status(Request $request): JsonResponse
    {
        $employee = self::employee($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $stored = $employee->getAttribute('face_embedding');
        $enrolled = $stored !== null && $stored !== '';
        $stale = $enrolled && BiometricEnrollment::isStale(
            $employee->getAttribute('face_enrolled_at'),
            $employee->getAttribute('face_model_version'),
        );

        $settings = $this->faces->settingsFor($this->branch($employee, $tenantId), $tenantId);

        return ApiResponse::success([
            'enrolled' => $enrolled && ! $stale,
            'needs_reenrollment' => $stale,
            'enrolled_at' => $employee->getAttribute('face_enrolled_at'),
            'model_version' => FaceEmbedding::MODEL_VERSION,
            'liveness_required' => $settings['liveness_required'],
            'min_quality_score' => FaceEnrollment::MIN_QUALITY_SCORE,
        ]);
    }

    /**
     * One-time by design: a second enrollment would let somebody quietly
     * replace the reference face after the first was approved.
     */
    private function assertNotAlreadyEnrolled(Employee $employee): void
    {
        $stored = $employee->getAttribute('face_embedding');

        if ($stored === null || $stored === '') {
            return;
        }

        // A model upgrade is the one case where re-enrollment needs no HR
        // reset: the old embedding cannot be compared against anything any
        // more, so refusing would strand the employee.
        $stale = BiometricEnrollment::isStale(
            $employee->getAttribute('face_enrolled_at'),
            $employee->getAttribute('face_model_version'),
        );

        if (! $stale) {
            throw new ApiFailure(__('messages.face_already_enrolled'), 409, 'FACE_ALREADY_ENROLLED');
        }
    }

    private function branch(Employee $employee, int $tenantId): ?Branch
    {
        return $employee->branch_id === null
            ? null
            : Branch::query()->forTenant($tenantId)->whereKey($employee->branch_id)->first();
    }

    private static function employee(Request $request): Employee
    {
        $employee = $request->attributes->get('employee');

        if (! $employee instanceof Employee) {
            throw new ApiFailure('Authentication required', 401);
        }

        return $employee;
    }
}
