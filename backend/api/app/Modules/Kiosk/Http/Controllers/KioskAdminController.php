<?php

declare(strict_types=1);

namespace App\Modules\Kiosk\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Modules\Kiosk\Domain\KioskPairing;
use App\Modules\Kiosk\Domain\RecognitionLog;
use App\Shared\Face\FaceEmbedding;
use App\Shared\Face\FaceEnrollment;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/kiosk/admin/{roster,enroll,close}.php.
 *
 * The administration area of a tablet already in service. Every call revalidates
 * the session and extends it, which is what lets a supervisor work through a
 * queue of thirty people without being thrown out mid-enrollment while an
 * abandoned screen still closes itself.
 */
final class KioskAdminController
{
    /**
     * Unenrolled people sort first, because that is the actual job on a first
     * morning with forty workers queuing at a door.
     */
    public function roster(Request $request): JsonResponse
    {
        $session = self::session($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $branchId = Value::int($request->attributes->get('branch_id'));

        $employees = DB::table('employees')
            ->where('tenant_id', $tenantId)->where('branch_id', $branchId)
            ->where('status', '!=', 'terminated')
            ->orderByRaw('(face_embedding IS NOT NULL) ASC')
            ->orderBy('name')
            ->get([
                'id', 'name', 'job_title', 'face_enrolled_at', 'face_quality_score',
                DB::raw('(face_embedding IS NOT NULL) AS face_enrolled'),
                DB::raw('(kiosk_pin_hash IS NOT NULL) AS has_kiosk_code'),
            ]);

        unset($session);

        return ApiResponse::success([
            'employees' => $employees->map(static fn (object $row): array => [
                'id' => Value::int($row->id),
                'name' => $row->name,
                'job_title' => $row->job_title,
                'face_enrolled' => Value::int($row->face_enrolled) === 1,
                'enrolled_at' => $row->face_enrolled_at,
                'quality_score' => is_numeric($row->face_quality_score) ? (float) $row->face_quality_score : null,
                'has_kiosk_code' => Value::int($row->has_kiosk_code) === 1,
            ])->all(),
            'model_version' => FaceEmbedding::MODEL_VERSION,
        ]);
    }

    /**
     * Enrolling a face at the tablet, so somebody without a smartphone can be
     * enrolled at all — without this, one-to-many identification could never
     * recognise them.
     *
     * Quality is judged here and not on the tablet. A patched kiosk reporting
     * perfect quality would poison the roster it later matches against.
     */
    public function enroll(Request $request): JsonResponse
    {
        $session = self::session($request);
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $branchId = Value::int($request->attributes->get('branch_id'));
        $stationId = Value::int($request->attributes->get('station_id'));

        $employeeId = Value::int($request->input('employee_id'));

        $employee = DB::table('employees')
            ->where('id', $employeeId)->where('tenant_id', $tenantId)
            ->first(['id', 'name', 'status', 'branch_id', 'face_embedding', 'face_enrolled_at', 'face_quality_score']);

        // Not "forbidden": from the tablet's point of view this employee simply
        // is not on its roster, and it was never offered them.
        if ($employee === null || Value::int($employee->branch_id) !== $branchId) {
            throw new ApiFailure(__('messages.employee_not_found'), 404, 'not_found');
        }

        if (Value::string($employee->status) === 'terminated') {
            throw new ApiFailure(__('messages.account_suspended'), 403, 'account_suspended');
        }

        if (Value::string($request->input('model_version')) !== FaceEmbedding::MODEL_VERSION) {
            throw new ApiFailure(__('messages.kiosk_quality_low'), 422, 'model_mismatch');
        }

        $embedding = FaceEmbedding::parse($request->input('embedding'));

        if ($embedding === null) {
            throw new ApiFailure(__('messages.kiosk_quality_low'), 422, 'bad_embedding');
        }

        $quality = Value::float($request->input('quality_score'));

        if ($quality < FaceEnrollment::MIN_QUALITY_SCORE) {
            RecognitionLog::record([
                'tenant_id' => $tenantId,
                'station_id' => $stationId,
                'branch_id' => $branchId,
                'employee_id' => $employeeId,
                'purpose' => 'enroll',
                'method' => 'face',
                'result' => 'not_enrolled',
                'accepted' => false,
                'match_score' => $quality,
            ]);

            throw new ApiFailure(__('messages.kiosk_quality_low'), 422, 'quality_too_low', [
                'quality_score' => $quality,
                'minimum' => FaceEnrollment::MIN_QUALITY_SCORE,
            ]);
        }

        // Replacing an enrollment is an explicit act. Without this, a second
        // person enrolled onto an existing employee is a silent overwrite, and
        // afterwards nothing distinguishes it from the original.
        $alreadyEnrolled = $employee->face_embedding !== null;

        if ($alreadyEnrolled && ! $request->boolean('confirm_replace')) {
            throw new ApiFailure(__('messages.kiosk_enroll_replaced'), 409, 'kiosk_enroll_replaced', [
                'enrolled_at' => $employee->face_enrolled_at,
                'quality_score' => is_numeric($employee->face_quality_score)
                    ? (float) $employee->face_quality_score
                    : null,
            ]);
        }

        FaceEnrollment::record(
            $employeeId,
            $tenantId,
            $embedding,
            FaceEnrollment::storeReferencePhoto($request->input('image'), $tenantId, $employeeId),
            $quality,
            FaceEmbedding::MODEL_VERSION,
        );

        // Provenance: which kiosk performed it. The administrator who
        // authorised the session is already on the station row.
        DB::table('employees')->where('id', $employeeId)->where('tenant_id', $tenantId)
            ->update(['face_enrolled_by_station_id' => $stationId]);

        RecognitionLog::record([
            'tenant_id' => $tenantId,
            'station_id' => $stationId,
            'branch_id' => $branchId,
            'employee_id' => $employeeId,
            'purpose' => 'enroll',
            'method' => 'face',
            'result' => 'matched',
            'accepted' => true,
            'match_score' => $quality,
        ]);

        return ApiResponse::success([
            'employee_id' => $employeeId,
            'name' => $employee->name,
            'enrolled_at' => TenantClock::now($tenantId)->format(DATE_ATOM),
            'replaced_previous' => $alreadyEnrolled,
            'authorised_by' => Value::int($session['admin_session_by'] ?? null),
            'message_key' => 'kiosk_enroll_done',
        ]);
    }

    public function close(Request $request): JsonResponse
    {
        $stationId = Value::int($request->attributes->get('station_id'));
        $token = self::sessionToken($request);

        // Idempotent: a supervisor tapping "done" on a session that already
        // timed out has achieved what they wanted.
        if (KioskPairing::touchAdminSession($stationId, $token) === null) {
            return ApiResponse::success(['closed' => true, 'already_closed' => true]);
        }

        KioskPairing::closeAdminSession($stationId);

        return ApiResponse::success([
            'closed' => true,
            'already_closed' => false,
            'release_kiosk_mode' => $request->boolean('release_kiosk_mode'),
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private static function session(Request $request): array
    {
        $station = KioskPairing::touchAdminSession(
            Value::int($request->attributes->get('station_id')),
            self::sessionToken($request),
        );

        if ($station === null) {
            throw new ApiFailure(__('messages.kiosk_admin_session_expired'), 401, 'kiosk_admin_session_expired');
        }

        return $station;
    }

    private static function sessionToken(Request $request): string
    {
        return Value::string($request->header('X-Kiosk-Admin-Session') ?? $request->input('admin_session'));
    }
}
