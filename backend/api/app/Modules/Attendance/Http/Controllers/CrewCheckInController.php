<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Modules\Attendance\Services\CrewPunchAction;
use App\Modules\Audit\Domain\AuditLog;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/attendance/crew_check_in.php.
 */
final class CrewCheckInController
{
    public function __construct(private readonly CrewPunchAction $crew) {}

    public function __invoke(Request $request): JsonResponse
    {
        $supervisor = $request->attributes->get('employee');
        if (! $supervisor instanceof Employee) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $isCheckOut = (bool) $request->input('is_check_out');

        $result = $this->crew->execute($supervisor, $tenantId, $request->all());

        AuditLog::record($tenantId, $supervisor->admin_id, 'attendance.crew_'.($isCheckOut ? 'check_out' : 'check_in'), null, null, [
            'supervisor_employee_id' => $supervisor->id,
            'recorded' => count($result['recorded']),
            'skipped' => count($result['skipped']),
        ]);

        return ApiResponse::success([
            'message' => $isCheckOut ? 'تم تسجيل انصراف الطاقم' : 'تم تسجيل حضور الطاقم',
            'count' => $result['count'],
            'recorded' => $result['recorded'],
            // Per-person reasons, so the app can say "28 recorded, 2 already
            // marked" instead of a bare success that hides what did not happen.
            'skipped' => $result['skipped'],
            'time' => $result['time'],
        ]);
    }
}
