<?php

declare(strict_types=1);

namespace App\Modules\Devices\Domain;

use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;

/**
 * The mapping between a User ID stored on a terminal and an employee.
 *
 * Rows appear two ways: the device announces its user list, so HR sees the IDs
 * without typing them, or an unknown ID punches. Either way the row starts
 * unlinked, and linking it is the whole setup task after a device is mounted.
 */
final class DeviceUsers
{
    /**
     * @return array<string, mixed>|null
     */
    public static function find(int $deviceId, string $deviceUserId): ?array
    {
        $row = DB::table('device_users')
            ->where('device_id', $deviceId)->where('device_user_id', trim($deviceUserId))
            ->first();

        return $row === null ? null : self::toArray($row);
    }

    /**
     * @return array<string, mixed>|null
     */
    public static function findById(int $id, int $tenantId): ?array
    {
        $row = DB::table('device_users')->where('id', $id)->where('tenant_id', $tenantId)->first();

        return $row === null ? null : self::toArray($row);
    }

    /**
     * Ensures a row exists for a User ID seen on a device, without disturbing
     * an existing link.
     *
     * A name only overwrites when the device actually sent one: a punch record
     * carries no name, and must not wipe the one an enrolment brought.
     *
     * @return array<string, mixed>|null
     */
    public static function ensure(
        int $deviceId,
        ?int $tenantId,
        string $deviceUserId,
        ?string $name = null,
        ?string $card = null,
        ?int $privilege = null,
    ): ?array {
        $deviceUserId = trim($deviceUserId);

        DB::statement(
            'INSERT INTO device_users (tenant_id, device_id, device_user_id, device_name, card_number, privilege)'
            .' VALUES (?, ?, ?, ?, ?, ?)'
            .' ON DUPLICATE KEY UPDATE'
            .'  device_name = COALESCE(VALUES(device_name), device_name),'
            .'  card_number = COALESCE(VALUES(card_number), card_number),'
            .'  privilege = COALESCE(VALUES(privilege), privilege),'
            .'  tenant_id = COALESCE(VALUES(tenant_id), tenant_id)',
            [$tenantId, $deviceId, $deviceUserId, $name, $card, $privilege],
        );

        return self::find($deviceId, $deviceUserId);
    }

    /**
     * Unlinked rows sort first: that list is the setup task, and it shrinks to
     * nothing as HR works through it.
     *
     * @return list<array<string, mixed>>
     */
    public static function listForDevice(int $deviceId, int $tenantId, ?string $filter = null): array
    {
        $rows = DB::table('device_users as du')
            ->leftJoin('employees as e', function (JoinClause $join): void {
                $join->on('e.id', '=', 'du.employee_id')->on('e.tenant_id', '=', 'du.tenant_id');
            })
            ->where('du.device_id', $deviceId)->where('du.tenant_id', $tenantId)
            ->when($filter === 'linked', fn (QueryBuilder $q): QueryBuilder => $q->whereNotNull('du.employee_id'))
            ->when(
                $filter === 'pending' || $filter === 'unlinked',
                fn (QueryBuilder $q): QueryBuilder => $q->whereNull('du.employee_id')
            )
            ->orderByRaw('du.employee_id IS NOT NULL')
            // Numerically where the ids are numbers, which they almost always
            // are: 2, 10, 11 rather than 10, 11, 2.
            ->orderByRaw('CAST(du.device_user_id AS UNSIGNED)')
            ->orderBy('du.device_user_id')
            ->get([
                'du.id', 'du.device_user_id', 'du.device_name', 'du.employee_id', 'du.card_number',
                'du.privilege', 'du.is_active', 'du.last_punch_at', 'du.linked_at',
                'e.name as employee_name', 'e.job_title as employee_job_title',
                DB::raw(
                    '(SELECT COUNT(*) FROM device_punches p'
                    ." WHERE p.device_id = du.device_id AND p.device_user_id = du.device_user_id AND p.state = 'unmatched')"
                    .' AS unmatched_punches'
                ),
            ])
            ->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    /**
     * Links a User ID to an employee, or unlinks it when the employee is null.
     */
    public static function link(int $id, int $tenantId, ?int $employeeId, ?int $adminId): void
    {
        DB::table('device_users')->where('id', $id)->where('tenant_id', $tenantId)->update([
            'employee_id' => $employeeId,
            'linked_by' => $employeeId === null ? null : $adminId,
            'linked_at' => $employeeId === null ? null : DB::raw('NOW()'),
        ]);
    }

    /**
     * One fingerprint per person per device.
     *
     * Two User IDs pointing at the same employee would fight over the same
     * attendance row all day.
     */
    public static function employeeTakenOnDevice(int $deviceId, int $employeeId, int $excludeId): bool
    {
        return DB::table('device_users')
            ->where('device_id', $deviceId)->where('employee_id', $employeeId)->where('id', '!=', $excludeId)
            ->exists();
    }

    public static function touchPunch(int $deviceId, string $deviceUserId, string $punchedAt): void
    {
        DB::update(
            'UPDATE device_users SET last_punch_at = GREATEST(COALESCE(last_punch_at, ?), ?)'
            .' WHERE device_id = ? AND device_user_id = ?',
            [$punchedAt, $punchedAt, $deviceId, trim($deviceUserId)],
        );
    }

    public static function adoptOrphans(int $deviceId, int $tenantId): void
    {
        DB::table('device_users')->where('device_id', $deviceId)->whereNull('tenant_id')
            ->update(['tenant_id' => $tenantId]);
    }

    /**
     * @return array<string, mixed>
     */
    private static function toArray(mixed $row): array
    {
        /** @var array<string, mixed> $columns */
        $columns = (array) $row;

        return $columns;
    }
}
