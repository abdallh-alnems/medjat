<?php

declare(strict_types=1);

namespace App\Modules\Warnings\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/warnings/{add,delete}.php.
 *
 * Disciplinary warnings on an employee's record.
 */
final class WarningController
{
    /** What a person may issue. The rest are written by the system. */
    private const ISSUABLE = ['verbal', 'written', 'final'];

    /**
     * Warnings the system raised itself.
     *
     * Part of the security trail rather than a manager's judgement, so nobody
     * can quietly remove the record of a device swap they made.
     */
    private const SYSTEM_TYPES = ['device_change', 'system'];

    public function create(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);

        $employeeId = Value::int($request->input('employee_id'));
        $type = Value::string($request->input('type'), 'verbal') ?: 'verbal';
        $reason = trim(Value::string($request->input('reason')));

        if ($employeeId <= 0) {
            throw new ApiFailure('employee_id is required', 422, 'employee_id_required');
        }

        // A warning with no reason is a mark on somebody's record that nobody
        // can explain later, including the person who left it.
        if ($reason === '') {
            throw new ApiFailure('reason is required', 422, 'reason_required');
        }

        if (! in_array($type, self::ISSUABLE, true)) {
            throw new ApiFailure('type must be one of: verbal, written, final', 422, 'invalid_type');
        }

        $exists = DB::table('employees')
            ->where('id', $employeeId)->where('tenant_id', $tenantId)->exists();

        if (! $exists) {
            throw new ApiFailure(__('messages.employee_not_found'), 404, 'not_found');
        }

        $id = (int) DB::table('warnings')->insertGetId([
            'tenant_id' => $tenantId,
            'employee_id' => $employeeId,
            'type' => $type,
            'reason' => $reason,
            'issued_by' => $admin->id,
        ]);

        AuditLog::record($tenantId, $admin->id, 'warning.add', 'employee', $employeeId, ['type' => $type]);

        return ApiResponse::success(['id' => $id, 'message' => 'Warning issued']);
    }

    public function delete(Request $request, int $id): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);

        $warning = $id > 0
            ? DB::table('warnings')->where('id', $id)->where('tenant_id', $tenantId)->first()
            : null;

        if ($warning === null) {
            throw new ApiFailure(__('messages.warning_not_found'), 404, 'not_found');
        }

        $type = Value::string($warning->type);

        if (in_array($type, self::SYSTEM_TYPES, true)) {
            throw new ApiFailure(__('messages.system_warning_undeletable'), 403, 'system_warning');
        }

        DB::table('warnings')->where('id', $id)->where('tenant_id', $tenantId)->delete();

        AuditLog::record(
            $tenantId, $admin->id, 'warning.delete', 'employee',
            Value::int($warning->employee_id),
            ['warning_id' => $id, 'type' => $type],
        );

        return ApiResponse::success(['message' => 'Warning deleted']);
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        return $admin;
    }
}
