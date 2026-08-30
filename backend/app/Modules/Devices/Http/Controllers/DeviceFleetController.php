<?php

declare(strict_types=1);

namespace App\Modules\Devices\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Devices\Domain\AttendanceDevice;
use App\Modules\Devices\Domain\DevicePunches;
use App\Modules\Devices\Domain\DeviceUsers;
use App\Modules\Devices\Domain\ZktecoProtocol;
use App\Shared\Http\ApiResponse;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/devices/{list,register,update,delete,command,punches}.php.
 *
 * Fingerprint terminals: claiming one, configuring it, letting it go, and
 * looking at what it has sent.
 */
final class DeviceFleetController
{
    public function index(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $devices = [];

        foreach (AttendanceDevice::listForTenant($tenantId) as $device) {
            $seen = Value::nullableInt($device['seconds_since_seen'] ?? null);

            $devices[] = [
                'id' => Value::int($device['id'] ?? null),
                'serial_number' => $device['serial_number'] ?? null,
                'name' => $device['name'] ?? null,
                'branch_id' => Value::nullableInt($device['branch_id'] ?? null),
                'branch_name' => $device['branch_name'] ?? null,
                'vendor' => $device['vendor'] ?? null,
                'model' => $device['model'] ?? null,
                'firmware' => $device['firmware'] ?? null,
                'status' => $device['status'] ?? null,
                // The single most useful thing this screen can say: a terminal
                // polls every few seconds, so silence means unplugged, off the
                // network, or pointed somewhere else.
                'is_online' => $seen !== null && $seen <= AttendanceDevice::ONLINE_GRACE_SECONDS,
                'seconds_since_seen' => $seen,
                'last_seen_at' => $device['last_seen_at'] ?? null,
                'last_punch_at' => $device['last_punch_at'] ?? null,
                'direction_mode' => $device['direction_mode'] ?? null,
                'min_interval_seconds' => Value::int($device['min_interval_seconds'] ?? null),
                'clock_offset_minutes' => Value::int($device['clock_offset_minutes'] ?? null),
                'keep_unmatched' => Value::int($device['keep_unmatched'] ?? null) === 1,
                'debug_logging' => Value::int($device['debug_logging'] ?? null) === 1,
                'linked_users' => Value::int($device['linked_users'] ?? null),
                'pending_users' => Value::int($device['pending_users'] ?? null),
                'punches_today' => Value::int($device['punches_today'] ?? null),
            ];
        }

        return ApiResponse::success(['devices' => $devices]);
    }

    /**
     * Claims a terminal by its serial and binds it to one branch.
     *
     * The serial is printed on the back, so whoever is standing next to it can
     * claim it. First claim wins and locks it to that company.
     */
    public function register(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;

        $serial = AttendanceDevice::normaliseSerial($request->input('serial_number'));
        $branchId = Value::int($request->input('branch_id'));

        if (preg_match('/^[A-Z0-9\-]{4,64}$/', $serial) !== 1) {
            throw new ApiFailure('Serial number looks invalid', 422, 'INVALID_SERIAL');
        }

        self::assertBranchExists($branchId, $tenantId);

        $name = trim(Value::string($request->input('name')));
        $device = AttendanceDevice::claim($serial, $tenantId, $branchId, $name !== '' ? mb_substr($name, 0, 100) : null, $adminId);
        $deviceId = Value::int($device['id'] ?? null);

        // Anything the device sent before it was claimed belongs to this
        // company now: its user list, and any punches from the day it was
        // mounted.
        DeviceUsers::adoptOrphans($deviceId, $tenantId);
        DevicePunches::adoptOrphans($deviceId, $tenantId);

        AuditLog::record($tenantId, $adminId, 'device.register', 'device', $deviceId, [
            'serial_number' => $serial,
            'branch_id' => $branchId,
        ]);

        return ApiResponse::success([
            'message' => 'Device registered',
            'device' => [
                'id' => $deviceId,
                'serial_number' => $device['serial_number'] ?? null,
                'name' => $device['name'] ?? null,
                'branch_id' => Value::nullableInt($device['branch_id'] ?? null),
                'status' => $device['status'] ?? null,
                'is_online' => self::isOnline($deviceId),
            ],
        ]);
    }

    public function update(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $deviceId = self::existing($request, $tenantId);

        $fields = [];

        if ($request->has('name')) {
            $name = trim(Value::string($request->input('name')));
            $fields['name'] = $name === '' ? null : mb_substr($name, 0, 100);
        }

        if ($request->has('branch_id')) {
            $branchId = Value::int($request->input('branch_id'));
            self::assertBranchExists($branchId, $tenantId);
            $fields['branch_id'] = $branchId;
        }

        if ($request->has('status')) {
            // 'unclaimed' is not settable here: releasing a device is its own
            // action, so the users and queued commands are cleaned up with it.
            $fields['status'] = self::oneOf($request, 'status', ['active', 'disabled']);
        }

        if ($request->has('direction_mode')) {
            $fields['direction_mode'] = self::oneOf($request, 'direction_mode', ['auto', 'device_status']);
        }

        if ($request->has('min_interval_seconds')) {
            $fields['min_interval_seconds'] = self::bounded($request, 'min_interval_seconds', 0, 3600, 'min_interval_range');
        }

        if ($request->has('clock_offset_minutes')) {
            $fields['clock_offset_minutes'] = self::bounded($request, 'clock_offset_minutes', -720, 720, 'clock_offset_range');
        }

        foreach (['keep_unmatched', 'debug_logging'] as $flag) {
            if ($request->has($flag)) {
                $fields[$flag] = $request->boolean($flag) ? 1 : 0;
            }
        }

        AttendanceDevice::update($deviceId, $tenantId, $fields);

        AuditLog::record($tenantId, $adminId, 'device.update', 'device', $deviceId, $fields);

        return ApiResponse::success(['message' => 'Device updated']);
    }

    /**
     * Releases a device back to unclaimed.
     *
     * The attendance already recorded from it stays: those hours were worked,
     * and they belong to the company, not to the hardware.
     */
    public function delete(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $deviceId = self::existing($request, $tenantId);

        $serial = DB::table('attendance_devices')->where('id', $deviceId)->value('serial_number');

        AttendanceDevice::release($deviceId, $tenantId);

        AuditLog::record($tenantId, $adminId, 'device.release', 'device', $deviceId, [
            'serial_number' => $serial,
        ]);

        return ApiResponse::success(['message' => 'Device released']);
    }

    /**
     * Queues a command for the terminal to collect on its next poll.
     *
     * We never dial the device — it lives behind the customer's router — so
     * every instruction waits here until the device asks for it.
     */
    public function command(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $deviceId = self::existing($request, $tenantId);
        $kind = Value::string($request->input('kind'));

        if (! in_array($kind, ZktecoProtocol::COMMAND_KINDS, true)) {
            throw new ApiFailure('Unsupported command', 422, 'UNSUPPORTED_COMMAND');
        }

        // The company's local time. Sending a UTC clock to a terminal would
        // shift every punch it records by the offset.
        $payload = ZktecoProtocol::commandPayload($kind, ['now' => TenantClock::timestamp($tenantId)]);

        if ($payload === null) {
            throw new ApiFailure('Unsupported command', 422, 'UNSUPPORTED_COMMAND');
        }

        $commandId = (int) DB::table('device_commands')->insertGetId([
            'tenant_id' => $tenantId,
            'device_id' => $deviceId,
            'kind' => $kind,
            'payload' => $payload,
            'created_by' => $adminId,
        ]);

        AuditLog::record($tenantId, $adminId, 'device.command', 'device', $deviceId, ['kind' => $kind]);

        $recent = DB::table('device_commands')
            ->where('device_id', $deviceId)->where('tenant_id', $tenantId)
            ->orderByDesc('id')->limit(10)
            ->get(['id', 'kind', 'state', 'created_at', 'sent_at'])
            ->map(static function (object $row): array {
                /** @var array<string, mixed> $columns */
                $columns = (array) $row;

                return $columns;
            })->all();

        return ApiResponse::success([
            'message' => 'Command queued',
            'command_id' => $commandId,
            'recent' => $recent,
        ]);
    }

    /**
     * The raw punch feed.
     *
     * The screen to open when somebody says "the machine didn't record me":
     * either the punch is here and shows why it was not applied, or it never
     * arrived — a very different conversation.
     */
    public function punches(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        $state = Value::string($request->query('state'));
        $state = in_array($state, DevicePunches::STATES, true) ? $state : null;

        $punches = DevicePunches::listForTenant($tenantId, [
            'device_id' => Value::int($request->query('device_id')) ?: null,
            'state' => $state,
            'employee_id' => Value::int($request->query('employee_id')) ?: null,
            'date_from' => self::date($request, 'date_from'),
            'date_to' => self::date($request, 'date_to'),
        ], Value::int($request->query('limit'), 100));

        return ApiResponse::success([
            'punches' => array_map(static fn (array $punch): array => [
                'id' => Value::int($punch['id'] ?? null),
                'device_id' => Value::int($punch['device_id'] ?? null),
                'device_name' => Value::string($punch['device_name'] ?? null) ?: $punch['serial_number'] ?? null,
                'device_user_id' => $punch['device_user_id'] ?? null,
                'device_user_name' => $punch['device_user_name'] ?? null,
                'employee_id' => Value::nullableInt($punch['employee_id'] ?? null),
                'employee_name' => $punch['employee_name'] ?? null,
                'punched_at' => $punch['punched_at'] ?? null,
                'direction' => $punch['direction'] ?? null,
                'state' => $punch['state'] ?? null,
                'note' => $punch['note'] ?? null,
                'attendance_id' => Value::nullableInt($punch['attendance_id'] ?? null),
            ], $punches),
        ]);
    }

    private static function isOnline(int $deviceId): bool
    {
        // Compared in SQL: these timestamps are written with the database's own
        // clock, and comparing them in PHP would be hours out.
        $row = DB::table('attendance_devices')->where('id', $deviceId)
            ->selectRaw('TIMESTAMPDIFF(SECOND, last_seen_at, NOW()) AS age')
            ->first();

        $age = $row === null ? null : Value::nullableInt($row->age);

        return $age !== null && $age <= AttendanceDevice::ONLINE_GRACE_SECONDS;
    }

    private static function existing(Request $request, int $tenantId): int
    {
        $deviceId = Value::int($request->input('device_id'));

        if ($deviceId <= 0 || AttendanceDevice::find($deviceId, $tenantId) === null) {
            throw new ApiFailure('Device not found', 404, 'not_found');
        }

        return $deviceId;
    }

    public static function assertBranchExists(int $branchId, int $tenantId): void
    {
        if ($branchId <= 0 || ! DB::table('branches')->where('id', $branchId)->where('tenant_id', $tenantId)->exists()) {
            throw new ApiFailure('Branch not found', 404, 'not_found');
        }
    }

    /**
     * @param  list<string>  $allowed
     */
    private static function oneOf(Request $request, string $field, array $allowed): string
    {
        $value = Value::string($request->input($field));

        if (! in_array($value, $allowed, true)) {
            throw new ApiFailure("Invalid {$field}", 422, 'invalid_'.$field);
        }

        return $value;
    }

    private static function bounded(Request $request, string $field, int $min, int $max, string $errorCode): int
    {
        $value = Value::int($request->input($field));

        if ($value < $min || $value > $max) {
            throw new ApiFailure("{$field} must be between {$min} and {$max}", 422, $errorCode);
        }

        return $value;
    }

    private static function date(Request $request, string $field): ?string
    {
        $value = Value::string($request->query($field));

        if ($value === '') {
            return null;
        }

        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $value) !== 1) {
            throw new ApiFailure("{$field} must be YYYY-MM-DD", 422, 'invalid_date');
        }

        return $value;
    }

    public static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        return $admin;
    }
}
