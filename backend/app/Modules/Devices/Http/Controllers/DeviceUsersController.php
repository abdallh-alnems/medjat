<?php

declare(strict_types=1);

namespace App\Modules\Devices\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Devices\Domain\AttendanceDevice;
use App\Modules\Devices\Domain\DevicePunches;
use App\Modules\Devices\Domain\DeviceUsers;
use App\Modules\Devices\Domain\PunchIngestor;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/devices/{users,link_user}.php.
 *
 * Matching the User IDs a terminal knows to the people they belong to. This is
 * the whole setup task after a device is mounted, and it shrinks to nothing as
 * HR works through it.
 */
final class DeviceUsersController
{
    public function __construct(private readonly PunchIngestor $ingestor) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $deviceId = Value::int($request->query('device_id'));

        if ($deviceId <= 0 || AttendanceDevice::find($deviceId, $tenantId) === null) {
            throw new ApiFailure('Device not found', 404, 'not_found');
        }

        $filter = Value::string($request->query('filter'));
        $filter = in_array($filter, ['linked', 'pending'], true) ? $filter : null;

        $users = array_map(static fn (array $user): array => [
            'id' => Value::int($user['id'] ?? null),
            'device_user_id' => $user['device_user_id'] ?? null,
            'device_name' => $user['device_name'] ?? null,
            'employee_id' => Value::nullableInt($user['employee_id'] ?? null),
            'employee_name' => $user['employee_name'] ?? null,
            'employee_job_title' => $user['employee_job_title'] ?? null,
            'card_number' => $user['card_number'] ?? null,
            'is_device_admin' => Value::int($user['privilege'] ?? null) > 0,
            'last_punch_at' => $user['last_punch_at'] ?? null,
            'linked_at' => $user['linked_at'] ?? null,
            'unmatched_punches' => Value::int($user['unmatched_punches'] ?? null),
        ], DeviceUsers::listForDevice($deviceId, $tenantId, $filter));

        return ApiResponse::success(['users' => $users]);
    }

    /**
     * Links a User ID to an employee, or unlinks it.
     *
     * Linking replays the punches that arrived before the link existed.
     * Without that, the first day of a new device — when everyone is enrolled
     * and everyone taps — would be lost while HR is still matching names to
     * numbers.
     */
    public function link(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = DeviceFleetController::admin($request)->id;

        $rowId = Value::int($request->input('device_user_row_id'));
        $row = $rowId > 0 ? DeviceUsers::findById($rowId, $tenantId) : null;

        if ($row === null) {
            throw new ApiFailure('Device user not found', 404, 'not_found');
        }

        $deviceId = Value::int($row['device_id'] ?? null);
        $device = AttendanceDevice::find($deviceId, $tenantId);

        if ($device === null) {
            throw new ApiFailure('Device not found', 404, 'not_found');
        }

        // Absent or null means unlink.
        $employeeId = $request->has('employee_id') ? Value::nullableInt($request->input('employee_id')) : null;

        if ($employeeId !== null) {
            $exists = DB::table('employees')->where('id', $employeeId)->where('tenant_id', $tenantId)->exists();

            if (! $exists) {
                throw new ApiFailure('Employee not found', 404, 'not_found');
            }

            // One fingerprint per person per device: two User IDs pointing at
            // the same employee would fight over the same attendance row all
            // day.
            if (DeviceUsers::employeeTakenOnDevice($deviceId, $employeeId, $rowId)) {
                throw new ApiFailure(
                    'This employee is already linked to another User ID on this device',
                    409,
                    'EMPLOYEE_ALREADY_LINKED',
                );
            }
        }

        DeviceUsers::link($rowId, $tenantId, $employeeId, $adminId);

        $replayed = array_fill_keys(DevicePunches::STATES, 0);

        if ($employeeId !== null) {
            $replayed = $this->ingestor->replayForDeviceUser(
                $device,
                Value::string($row['device_user_id'] ?? null),
            );
        }

        AuditLog::record(
            $tenantId,
            $adminId,
            $employeeId === null ? 'device.unlink_user' : 'device.link_user',
            'employee',
            $employeeId,
            ['device_id' => $deviceId, 'device_user_id' => $row['device_user_id'] ?? null],
        );

        return ApiResponse::success([
            'message' => $employeeId === null ? 'User unlinked' : 'User linked',
            'replayed' => $replayed,
        ]);
    }
}
