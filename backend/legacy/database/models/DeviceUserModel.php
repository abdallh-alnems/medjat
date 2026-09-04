<?php

/**
 * The mapping between a User ID stored on a terminal and a Permedjat employee.
 *
 * Rows appear here two ways: the device announces its user list (so HR sees
 * the IDs without typing them), or an unknown ID punches. Either way the row
 * starts unlinked, and linking it is a one-tap job in the app.
 */
final class DeviceUserModel {
    public static function find(int $deviceId, string $deviceUserId): ?array {
        return Database::fetchOne(
            "SELECT * FROM device_users WHERE device_id = ? AND device_user_id = ? LIMIT 1",
            [$deviceId, trim($deviceUserId)]
        );
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM device_users WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    /**
     * Ensures a row exists for a User ID seen on a device, without disturbing
     * an existing link. Returns the row.
     *
     * `$name` only overwrites when the device actually sent one — a punch
     * record carries no name, and must not wipe the name an enrolment brought.
     */
    public static function ensure(
        int $deviceId,
        ?int $tenantId,
        string $deviceUserId,
        ?string $name = null,
        ?string $card = null,
        ?int $privilege = null
    ): array {
        $deviceUserId = trim($deviceUserId);

        Database::execute(
            "INSERT INTO device_users (tenant_id, device_id, device_user_id, device_name, card_number, privilege)
             VALUES (?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
                device_name = COALESCE(VALUES(device_name), device_name),
                card_number = COALESCE(VALUES(card_number), card_number),
                privilege   = COALESCE(VALUES(privilege), privilege),
                tenant_id   = COALESCE(VALUES(tenant_id), tenant_id)",
            [$tenantId, $deviceId, $deviceUserId, $name, $card, $privilege]
        );

        return self::find($deviceId, $deviceUserId);
    }

    /** Device users for one device, newest-first with the employee's name attached. */
    public static function listForDevice(int $deviceId, int $tenantId, ?string $filter = null): array {
        $where = "du.device_id = ? AND du.tenant_id = ?";
        $params = [$deviceId, $tenantId];

        if ($filter === 'linked') {
            $where .= " AND du.employee_id IS NOT NULL";
        } elseif ($filter === 'pending') {
            $where .= " AND du.employee_id IS NULL";
        }

        return Database::fetchAll(
            "SELECT du.id, du.device_user_id, du.device_name, du.employee_id, du.card_number,
                    du.privilege, du.is_active, du.last_punch_at, du.linked_at,
                    e.name AS employee_name, e.job_title AS employee_job_title,
                    (SELECT COUNT(*) FROM device_punches p
                      WHERE p.device_id = du.device_id
                        AND p.device_user_id = du.device_user_id
                        AND p.state = 'unmatched') AS unmatched_punches
             FROM device_users du
             LEFT JOIN employees e ON e.id = du.employee_id AND e.tenant_id = du.tenant_id
             WHERE $where
             ORDER BY du.employee_id IS NOT NULL, CAST(du.device_user_id AS UNSIGNED), du.device_user_id",
            $params
        );
    }

    /** Every device user across the tenant that is still waiting to be linked. */
    public static function pendingCount(int $tenantId): int {
        $row = Database::fetchOne(
            "SELECT COUNT(*) AS c FROM device_users WHERE tenant_id = ? AND employee_id IS NULL",
            [$tenantId]
        );
        return (int) ($row['c'] ?? 0);
    }

    public static function link(int $id, int $tenantId, ?int $employeeId, ?int $adminId): void {
        Database::execute(
            "UPDATE device_users
             SET employee_id = ?, linked_by = ?, linked_at = CASE WHEN ? IS NULL THEN NULL ELSE NOW() END
             WHERE id = ? AND tenant_id = ?",
            [$employeeId, $employeeId === null ? null : $adminId, $employeeId, $id, $tenantId]
        );
    }

    /** True when this employee is already taken by another User ID on the same device. */
    public static function employeeTakenOnDevice(int $deviceId, int $employeeId, int $excludeId): bool {
        $row = Database::fetchOne(
            "SELECT id FROM device_users
             WHERE device_id = ? AND employee_id = ? AND id <> ? LIMIT 1",
            [$deviceId, $employeeId, $excludeId]
        );
        return $row !== null;
    }

    public static function touchPunch(int $deviceId, string $deviceUserId, string $punchedAt): void {
        Database::execute(
            "UPDATE device_users
             SET last_punch_at = GREATEST(COALESCE(last_punch_at, ?), ?)
             WHERE device_id = ? AND device_user_id = ?",
            [$punchedAt, $punchedAt, $deviceId, $deviceUserId]
        );
    }
}
