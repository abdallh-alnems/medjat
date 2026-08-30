<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Employee;
use App\Modules\Attendance\Services\SyncOfflineAction;
use App\Modules\Audit\Domain\AuditLog;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/attendance/sync_offline.php.
 */
final class SyncOfflineController
{
    public function __construct(private readonly SyncOfflineAction $sync) {}

    public function __invoke(Request $request): JsonResponse
    {
        $employee = $request->attributes->get('employee');
        if (! $employee instanceof Employee) {
            throw new ApiFailure('Authentication required', 401);
        }

        $records = $request->input('records');
        if (! is_array($records) || $records === []) {
            throw new ApiFailure('Records array is required', 400, 'records_required');
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $result = $this->sync->execute($records, $employee, $tenantId);

        AuditLog::record($tenantId, $employee->admin_id, 'attendance.offline_sync', null, null, [
            'synced' => $result['synced'],
            'failed' => $result['failed'],
        ]);

        return ApiResponse::success($result);
    }
}
