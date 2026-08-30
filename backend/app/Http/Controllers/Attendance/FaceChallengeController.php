<?php

declare(strict_types=1);

namespace App\Http\Controllers\Attendance;

use App\Domain\Face\FaceChallenge;
use App\Domain\Face\FaceEmbedding;
use App\Domain\Face\FaceMatcher;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Branch;
use App\Models\Employee;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/attendance/face_challenge.php.
 */
final class FaceChallengeController
{
    private const PURPOSES = ['check_in', 'check_out', 'enroll'];

    public function __construct(private readonly FaceMatcher $faces) {}

    public function __invoke(Request $request): JsonResponse
    {
        $employee = $request->attributes->get('employee');
        if (! $employee instanceof Employee) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $purpose = Value::string($request->input('purpose'), 'check_in');

        if (! in_array($purpose, self::PURPOSES, true)) {
            throw new ApiFailure('purpose must be check_in, check_out or enroll', 422, 'invalid_purpose');
        }

        // Enrolment is the one purpose that does not need an existing
        // enrolment; the other two are pointless without one, so this fails
        // early with a clear code rather than letting the punch reject later.
        $enrolled = $employee->getAttribute('face_embedding');
        if ($purpose !== 'enroll' && ($enrolled === null || $enrolled === '')) {
            throw new ApiFailure('لم يتم تسجيل بصمة الوجه لحسابك', 400, 'FACE_NOT_ENROLLED');
        }

        $branch = $employee->branch_id === null
            ? null
            : Branch::query()->forTenant($tenantId)->whereKey($employee->branch_id)->first();

        $challenge = FaceChallenge::issue($tenantId, $employee->id, $purpose);

        return ApiResponse::success([
            'nonce' => $challenge['nonce'],
            'challenge' => $challenge['challenge'],
            'expires_in' => $challenge['expires_in'],
            'liveness_required' => $this->faces->settingsFor($branch, $tenantId)['liveness_required'],
            'model_version' => FaceEmbedding::MODEL_VERSION,
        ]);
    }
}
