<?php

declare(strict_types=1);

namespace App\Modules\Biometric\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Http\Middleware\RequireBranchAccess;
use App\Models\Admin;
use App\Models\Employee;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Biometric\Domain\BiometricEnrollment;
use App\Shared\Face\FaceEmbedding;
use App\Shared\Face\FaceEnrollment;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Ports of api/app/biometric/{enroll_face,enroll_fingerprint,delete,status}.php.
 *
 * The HR side of biometrics: recording a face or fingerprint for somebody else,
 * clearing one, and reading what is held.
 */
final class EnrollmentController
{
    public function enrollFace(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);
        $employee = $this->subject($request, $tenantId, $admin);

        // A malformed vector would be stored happily and then fail every
        // check-in with an opaque error, so it is refused at the door.
        $vector = FaceEmbedding::parse($request->input('embedding'));

        if ($vector === null) {
            throw new ApiFailure(
                'embedding must be a numeric vector of 128, 192 or 512 finite values',
                422,
                'invalid_embedding',
            );
        }

        $photoUrl = FaceEnrollment::storeReferencePhoto(
            $request->input('image_base64'), $tenantId, $employee->id,
        );

        FaceEnrollment::record(
            $employee->id,
            $tenantId,
            $vector,
            $photoUrl,
            Value::float($request->input('quality_score')),
            Value::string($request->input('model_version')) ?: FaceEmbedding::MODEL_VERSION,
        );

        AuditLog::record($tenantId, $admin->id, 'biometric.enroll_face', 'employee', $employee->id);

        return ApiResponse::success([
            'employee_id' => $employee->id,
            'status' => 'face_enrolled',
        ], 201);
    }

    public function enrollFingerprint(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);
        $employee = $this->subject($request, $tenantId, $admin);

        $template = Value::string($request->input('template_base64'));

        if ($template === '') {
            throw new ApiFailure('template_base64 is required', 422, 'template_base64_required');
        }

        // The template itself is not kept — see BiometricEnrollment. It is
        // still required here so a caller cannot register an enrollment that
        // the terminal never actually captured.
        BiometricEnrollment::recordFingerprint($employee->id, $tenantId);

        AuditLog::record($tenantId, $admin->id, 'biometric.enroll_fingerprint', 'employee', $employee->id);

        return ApiResponse::success([
            'employee_id' => $employee->id,
            'status' => 'fingerprint_enrolled',
        ], 201);
    }

    /**
     * Clearing an enrollment is also how a re-enrollment is authorised: the
     * self-service path is one-time, so this is the only way back to the
     * camera.
     */
    public function delete(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);

        $type = Value::string($request->input('type'), 'both') ?: 'both';

        if (! in_array($type, BiometricEnrollment::TYPES, true)) {
            throw new ApiFailure('type must be one of: face, fingerprint, both', 422, 'invalid_type');
        }

        $employeeId = Value::int($request->input('employee_id'));
        $employee = Employee::query()->where('id', $employeeId)->where('tenant_id', $tenantId)->first();

        if ($employee === null) {
            throw new ApiFailure('Employee not found', 404, 'employee_not_found');
        }

        if ($type === 'face' || $type === 'both') {
            BiometricEnrollment::clearFace($employee->id, $tenantId);
        }

        if ($type === 'fingerprint' || $type === 'both') {
            BiometricEnrollment::clearFingerprint($employee->id, $tenantId);
        }

        AuditLog::record($tenantId, $admin->id, 'biometric.delete', 'employee', $employee->id);

        return ApiResponse::success(['employee_id' => $employee->id, 'deleted_type' => $type]);
    }

    public function status(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $status = BiometricEnrollment::status(Value::int($request->query('employee_id')), $tenantId);

        if ($status === null) {
            throw new ApiFailure('Employee not found', 404, 'employee_not_found');
        }

        return ApiResponse::success($status);
    }

    private function subject(Request $request, int $tenantId, Admin $admin): Employee
    {
        $employeeId = Value::int($request->input('employee_id'));

        if ($employeeId <= 0) {
            throw new ApiFailure('employee_id is required', 422, 'employee_id_required');
        }

        $employee = Employee::query()->where('id', $employeeId)->where('tenant_id', $tenantId)->first();

        if ($employee === null) {
            throw new ApiFailure('Employee not found', 404, 'employee_not_found');
        }

        RequireBranchAccess::assert($admin, $employee->branch_id);

        return $employee;
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        return $admin;
    }
}
