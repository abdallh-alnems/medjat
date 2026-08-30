<?php

declare(strict_types=1);

namespace App\Modules\Shifts\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Shifts\Domain\Shifts;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Ports of api/app/shifts/*.php.
 *
 * Named working hours, and who is on them.
 */
final class ShiftController
{
    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $branchId = Value::int($request->query('branch_id')) ?: null;

        return ApiResponse::success(['items' => Shifts::forTenant($tenantId, $branchId)]);
    }

    public function create(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;

        $name = trim(Value::string($request->input('name')));
        $start = Value::string($request->input('start_time'));
        $end = Value::string($request->input('end_time'));

        if ($name === '' || $start === '' || $end === '') {
            throw new ApiFailure(
                'Name, start time, and end time are required',
                422,
                'name_start_time_end_time',
            );
        }

        $id = Shifts::create($tenantId, [
            'name' => $name,
            'start_time' => $start,
            'end_time' => $end,
            'branch_id' => Value::int($request->input('branch_id')) ?: null,
        ]);

        AuditLog::record($tenantId, $adminId, 'shift.create', 'shift', $id);

        return ApiResponse::success(['id' => $id, 'message' => 'Shift created'], 201);
    }

    public function update(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $id = self::existing($request, $tenantId);

        $changes = [];

        foreach (['name', 'start_time', 'end_time'] as $field) {
            if ($request->has($field)) {
                $changes[$field] = Value::string($request->input($field));
            }
        }

        if ($request->has('branch_id')) {
            $changes['branch_id'] = Value::int($request->input('branch_id')) ?: null;
        }

        if ($request->has('is_active')) {
            $changes['is_active'] = $request->boolean('is_active') ? 1 : 0;
        }

        Shifts::update($id, $tenantId, $changes);

        AuditLog::record($tenantId, $adminId, 'shift.update', 'shift', $id);

        return ApiResponse::success(['message' => 'Updated']);
    }

    /**
     * Deleting a shift, without changing anybody's hours.
     *
     * Two ways out, and both preserve the schedule. Name another shift and
     * everybody moves onto it, roster and all. Name none and each member's own
     * working hours are set to what the shift said, so their day is unchanged
     * after the shift is gone.
     */
    public function delete(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $id = self::existing($request, $tenantId);
        $shift = Shifts::find($id, $tenantId) ?? [];

        $transferTo = Value::int($request->input('transfer_to_shift_id'));
        $scheduleMoved = 0;

        if ($transferTo > 0) {
            if ($transferTo === $id) {
                throw new ApiFailure(
                    'Cannot transfer employees to the shift being deleted',
                    422,
                    'cannot_transfer_employees_shift_being',
                );
            }

            if (Shifts::find($transferTo, $tenantId) === null) {
                throw new ApiFailure('Target shift not found', 422, 'target_shift_not_found');
            }

            $affected = Shifts::transferEmployees($id, $transferTo, $tenantId);
            $scheduleMoved = Shifts::transferSchedule($id, $transferTo, $tenantId);
            $action = 'transferred';
        } else {
            $affected = Shifts::applyTimesToEmployees(
                $id,
                Value::string($shift['start_time'] ?? null),
                Value::string($shift['end_time'] ?? null),
                $tenantId,
            );
            $action = 'kept_times';
        }

        Shifts::delete($id, $tenantId);

        AuditLog::record($tenantId, $adminId, 'shift.delete', 'shift', $id, [
            'action' => $action,
            'affected' => $affected,
            'schedule_moved' => $scheduleMoved,
        ]);

        return ApiResponse::success([
            'message' => 'Shift deleted',
            'action' => $action,
            'affected' => $affected,
            'schedule_moved' => $scheduleMoved,
        ]);
    }

    public function assign(Request $request): JsonResponse
    {
        return $this->membership($request, true);
    }

    public function unassign(Request $request): JsonResponse
    {
        return $this->membership($request, false);
    }

    private function membership(Request $request, bool $assigning): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;

        $shiftId = Value::int($request->input('shift_id'));
        $raw = $request->input('employee_ids');

        if ($shiftId <= 0 || ! is_array($raw) || $raw === []) {
            throw new ApiFailure(
                'shift_id and employee_ids array required',
                422,
                'shift_id_employee_ids_array',
            );
        }

        if (Shifts::find($shiftId, $tenantId) === null) {
            throw new ApiFailure('Shift not found', 404, 'not_found');
        }

        $employeeIds = array_values(array_filter(
            array_map(static fn (mixed $id): int => Value::int($id), $raw),
            static fn (int $id): bool => $id > 0,
        ));

        $count = $assigning
            ? Shifts::assign($shiftId, $employeeIds, $tenantId)
            : Shifts::unassign($shiftId, $employeeIds, $tenantId);

        AuditLog::record(
            $tenantId, $adminId,
            $assigning ? 'shift.assign' : 'shift.unassign',
            'shift', $shiftId, ['count' => $count],
        );

        return ApiResponse::success([$assigning ? 'assigned' : 'unassigned' => $count]);
    }

    private static function existing(Request $request, int $tenantId): int
    {
        $id = Value::int($request->input('id')) ?: Value::int($request->query('id'));

        if ($id <= 0) {
            throw new ApiFailure('Shift ID required', 422, 'shift_id_required');
        }

        if (Shifts::find($id, $tenantId) === null) {
            throw new ApiFailure('Shift not found', 404, 'not_found');
        }

        return $id;
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
