<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Shared\Http\ApiResponse;
use App\Shared\Security\AttendanceSecurityLog;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/attendance/security_log.php.
 *
 * The app reports a condition it refused to punch under. Everything here is
 * client-asserted and therefore useful only as a signal, never as evidence —
 * which is why nothing is decided on it and the reason is matched against a
 * literal list rather than stored as sent.
 */
final class SecurityLogController
{
    /** @var list<string> */
    private const REASONS = ['mock_location', 'rooted', 'jailbroken', 'vpn', 'no_local_biometric'];

    public function __invoke(Request $request): JsonResponse
    {
        $employee = $request->attributes->get('employee');
        if (! $employee instanceof Employee) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        $reason = Value::string($request->input('reason'));
        if (! in_array($reason, self::REASONS, true)) {
            throw new ApiFailure('Invalid reason', 400, 'invalid_reason');
        }

        $branchId = Value::int($request->input('branch_id'));

        AttendanceSecurityLog::record(
            Value::int($request->attributes->get('tenant_id')),
            $employee->id,
            $branchId > 0 ? $branchId : null,
            $reason,
            'blocked',
            $request->has('latitude') ? Value::float($request->input('latitude')) : null,
            $request->has('longitude') ? Value::float($request->input('longitude')) : null,
        );

        return ApiResponse::success(['logged' => true]);
    }
}
