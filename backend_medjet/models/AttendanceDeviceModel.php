<?php

/**
 * Biometric attendance terminals (ZKTeco ADMS "push" devices).
 *
 * A device row exists in one of two states:
 *   - unclaimed: the terminal has contacted us but no company has entered its
 *     serial number yet. Carries no tenant data.
 *   - active/disabled: claimed by exactly one tenant and bound to one branch.
 *
 * Claiming is first-come-first-served on the serial number, which is printed
 * on the device — whoever physically holds it owns it.
 */
final class AttendanceDeviceModel {
    /** Serial numbers are compared upper-cased and trimmed everywhere. */
    public static function normaliseSerial($raw): string {
        return strtoupper(trim((string) $raw));
    }

    public static function findBySerial(string $serial): ?array {
        return Database::fetchOne(
            "SELECT * FROM attendance_devices WHERE serial_number = ? LIMIT 1",
            [self::normaliseSerial($serial)]
        );
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM attendance_devices WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    /**
     * The stand-in device for file imports at a branch, created on first use.
     *
     * A punch has to belong to a device row — that is what carries the branch,
     * the clock offset and the repeat-tap window. A customer importing a CSV
     * usually has no registered terminal at all (that is why they are importing
     * a file), so one is synthesised per branch.
     *
     * The serial is namespaced and unclaimable: `normaliseSerial` upper-cases,
     * and register.php rejects anything that is not `[A-Z0-9-]{4,64}`, so a real
     * terminal can never collide with `FILE-T3-B7` — and nobody can type it in
     * to hijack an import stream, because these ids are per tenant already.
     */
    public static function ensureFileImportDevice(int $tenantId, int $branchId, ?int $adminId): array {
        $serial = self::normaliseSerial("FILE-T{$tenantId}-B{$branchId}");
        $existing = self::findBySerial($serial);
        if ($existing !== null) {
            return $existing;
        }

        Database::execute(
            "INSERT INTO attendance_devices
                (tenant_id, branch_id, serial_number, name, vendor, status, claimed_by, claimed_at, first_seen_at)
             VALUES (?, ?, ?, ?, 'other', 'active', ?, NOW(), NOW())
             ON DUPLICATE KEY UPDATE id = id",
            [$tenantId, $branchId, $serial, 'استيراد ملف', $adminId]
        );

        return self::findBySerial($serial);
    }

    /**
     * Records that a serial number just talked to us, creating the unclaimed
     * row on first contact. Returns the device row.
     *
     * Called on the hot device path, so it stays a single upsert.
     */
    public static function recordContact(string $serial, ?string $ip): array {
        $serial = self::normaliseSerial($serial);

        Database::execute(
            "INSERT INTO attendance_devices (serial_number, status, first_seen_at, last_seen_at, last_ip)
             VALUES (?, 'unclaimed', NOW(), NOW(), ?)
             ON DUPLICATE KEY UPDATE last_seen_at = NOW(), last_ip = VALUES(last_ip)",
            [$serial, $ip]
        );

        $device = self::findBySerial($serial);
        if ($device === null) {
            // Only reachable if the row was deleted between the two statements.
            throw new RuntimeException('Device row vanished for serial ' . $serial);
        }
        return $device;
    }

    /** Stores whatever the device volunteered about itself during the handshake. */
    public static function updateInfo(int $deviceId, array $info): void {
        $sets = [];
        $params = [];
        foreach (['model' => 'model', 'firmware' => 'firmware', 'user_count' => 'user_count'] as $key => $column) {
            if (array_key_exists($key, $info) && $info[$key] !== null && $info[$key] !== '') {
                $sets[] = "`$column` = ?";
                $params[] = $info[$key];
            }
        }
        if (!$sets) {
            return;
        }
        $params[] = $deviceId;
        Database::execute(
            "UPDATE attendance_devices SET " . implode(', ', $sets) . " WHERE id = ?",
            $params
        );
    }

    public static function touchPunch(int $deviceId, string $punchedAt): void {
        Database::execute(
            "UPDATE attendance_devices
             SET last_punch_at = GREATEST(COALESCE(last_punch_at, ?), ?)
             WHERE id = ?",
            [$punchedAt, $punchedAt, $deviceId]
        );
    }

    /**
     * Binds an unclaimed device to a tenant + branch.
     *
     * A device already owned by ANOTHER tenant is refused: silently moving it
     * would hand that company's punch stream to a stranger.
     */
    public static function claim(
        string $serial,
        int $tenantId,
        int $branchId,
        ?string $name,
        ?int $adminId
    ): array {
        $serial = self::normaliseSerial($serial);
        $existing = self::findBySerial($serial);

        if ($existing !== null
            && $existing['tenant_id'] !== null
            && (int) $existing['tenant_id'] !== $tenantId) {
            Response::fail(
                'This device is already registered to another company',
                409,
                'DEVICE_ALREADY_CLAIMED'
            );
        }

        if ($existing === null) {
            // Registered before the terminal ever dialled in. Legitimate — HR
            // usually types the serial off the box while the electrician is
            // still mounting it — so the row is created ready and waiting.
            Database::execute(
                "INSERT INTO attendance_devices
                    (tenant_id, branch_id, serial_number, name, status, claimed_by, claimed_at)
                 VALUES (?, ?, ?, ?, 'active', ?, NOW())",
                [$tenantId, $branchId, $serial, $name, $adminId]
            );
        } else {
            Database::execute(
                "UPDATE attendance_devices
                 SET tenant_id = ?, branch_id = ?, name = COALESCE(?, name),
                     status = 'active', claimed_by = ?, claimed_at = NOW()
                 WHERE id = ?",
                [$tenantId, $branchId, $name, $adminId, $existing['id']]
            );
        }

        return self::findBySerial($serial);
    }

    /**
     * Devices with everything the list screen needs to answer "is it working?".
     *
     * The freshness of `last_seen_at` is computed in SQL on purpose: those
     * timestamps are written with MySQL's NOW() (company local time) while PHP
     * runs in UTC, so comparing them in PHP would be three hours wrong.
     */
    public static function listForTenant(int $tenantId): array {
        return Database::fetchAll(
            "SELECT d.*, b.name AS branch_name,
                    TIMESTAMPDIFF(SECOND, d.last_seen_at, NOW()) AS seconds_since_seen,
                    (SELECT COUNT(*) FROM device_users du
                      WHERE du.device_id = d.id AND du.employee_id IS NOT NULL) AS linked_users,
                    (SELECT COUNT(*) FROM device_users du
                      WHERE du.device_id = d.id AND du.employee_id IS NULL) AS pending_users,
                    (SELECT COUNT(*) FROM device_punches p
                      WHERE p.device_id = d.id AND DATE(p.punched_at) = CURDATE()) AS punches_today
             FROM attendance_devices d
             LEFT JOIN branches b ON b.id = d.branch_id AND b.tenant_id = d.tenant_id
             WHERE d.tenant_id = ?
             ORDER BY d.id DESC",
            [$tenantId]
        );
    }

    public static function update(int $deviceId, int $tenantId, array $fields): void {
        $allowed = [
            'name', 'branch_id', 'status', 'direction_mode',
            'min_interval_seconds', 'clock_offset_minutes', 'keep_unmatched', 'debug_logging',
        ];
        $sets = [];
        $params = [];
        foreach ($allowed as $column) {
            if (array_key_exists($column, $fields)) {
                $sets[] = "`$column` = ?";
                $params[] = $fields[$column];
            }
        }
        if (!$sets) {
            return;
        }
        $params[] = $deviceId;
        $params[] = $tenantId;
        Database::execute(
            "UPDATE attendance_devices SET " . implode(', ', $sets) . " WHERE id = ? AND tenant_id = ?",
            $params
        );
    }

    /**
     * Releases a device back to unclaimed so it can be moved to another company
     * (resale, wrong company entered). The punch history stays: it belongs to
     * the company that recorded it, not to the hardware.
     */
    public static function release(int $deviceId, int $tenantId): void {
        Database::execute(
            "UPDATE attendance_devices
             SET tenant_id = NULL, branch_id = NULL, status = 'unclaimed',
                 claimed_by = NULL, claimed_at = NULL, name = NULL
             WHERE id = ? AND tenant_id = ?",
            [$deviceId, $tenantId]
        );
        Database::execute("DELETE FROM device_users WHERE device_id = ? AND tenant_id = ?", [$deviceId, $tenantId]);
        Database::execute("DELETE FROM device_commands WHERE device_id = ? AND tenant_id = ?", [$deviceId, $tenantId]);
    }

    /** True once the terminal has contacted us within the last few minutes. */
    public static function isOnline(?string $lastSeenAt, int $graceSeconds = 300): bool {
        if (!$lastSeenAt) {
            return false;
        }
        $row = Database::fetchOne(
            "SELECT TIMESTAMPDIFF(SECOND, ?, NOW()) AS age",
            [$lastSeenAt]
        );
        return $row !== null && (int) $row['age'] <= $graceSeconds;
    }
}
