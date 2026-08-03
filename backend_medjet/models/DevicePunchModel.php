<?php

/**
 * The raw punch log pushed up by attendance terminals.
 *
 * This table is written before any business rule is applied. The device wipes
 * its own copy as soon as we answer OK, so a punch that is not stored here is
 * gone forever — nothing in this class may refuse a row.
 */
final class DevicePunchModel {
    /**
     * Stores one punch. Returns the row id plus whether the device had already
     * sent it (terminals re-send their whole buffer after a power cut).
     */
    public static function record(
        int $deviceId,
        ?int $tenantId,
        string $deviceUserId,
        string $punchedAt,
        ?int $statusCode,
        ?int $verifyMode,
        ?string $workCode,
        ?string $rawLine
    ): array {
        $affected = Database::execute(
            "INSERT INTO device_punches
                (tenant_id, device_id, device_user_id, punched_at, status_code, verify_mode, work_code, raw_line)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE id = id",
            [$tenantId, $deviceId, trim($deviceUserId), $punchedAt, $statusCode, $verifyMode, $workCode, $rawLine]
        );

        $row = Database::fetchOne(
            "SELECT id, state FROM device_punches
             WHERE device_id = ? AND device_user_id = ? AND punched_at = ? LIMIT 1",
            [$deviceId, trim($deviceUserId), $punchedAt]
        );

        return [
            'id' => (int) ($row['id'] ?? 0),
            'duplicate' => $affected === 0,
            'state' => $row['state'] ?? null,
        ];
    }

    public static function markResult(
        int $punchId,
        string $state,
        ?int $employeeId = null,
        ?string $direction = null,
        ?int $attendanceId = null,
        ?string $note = null
    ): void {
        Database::execute(
            "UPDATE device_punches
             SET state = ?, employee_id = ?, direction = ?, attendance_id = ?, note = ?
             WHERE id = ?",
            [$state, $employeeId, $direction, $attendanceId, $note !== null ? mb_substr($note, 0, 191) : null, $punchId]
        );
    }

    /**
     * Punches recorded for a User ID before anyone linked it to an employee.
     * Replayed the moment the link is made, so the first day of use is not
     * lost while HR is still matching names.
     */
    public static function unmatchedFor(int $deviceId, string $deviceUserId, int $limit = 500): array {
        $limit = max(1, min(2000, $limit));
        return Database::fetchAll(
            "SELECT * FROM device_punches
             WHERE device_id = ? AND device_user_id = ? AND state = 'unmatched'
             ORDER BY punched_at ASC
             LIMIT $limit",
            [$deviceId, trim($deviceUserId)]
        );
    }

    public static function listForTenant(int $tenantId, array $filters = [], int $limit = 100): array {
        $where = ['p.tenant_id = ?'];
        $params = [$tenantId];

        if (!empty($filters['device_id'])) {
            $where[] = 'p.device_id = ?';
            $params[] = (int) $filters['device_id'];
        }
        if (!empty($filters['state'])) {
            $where[] = 'p.state = ?';
            $params[] = $filters['state'];
        }
        if (!empty($filters['employee_id'])) {
            $where[] = 'p.employee_id = ?';
            $params[] = (int) $filters['employee_id'];
        }
        if (!empty($filters['date_from'])) {
            $where[] = 'p.punched_at >= ?';
            $params[] = $filters['date_from'] . ' 00:00:00';
        }
        if (!empty($filters['date_to'])) {
            $where[] = 'p.punched_at <= ?';
            $params[] = $filters['date_to'] . ' 23:59:59';
        }

        $limit = max(1, min(500, $limit));

        return Database::fetchAll(
            "SELECT p.id, p.device_id, p.device_user_id, p.employee_id, p.punched_at,
                    p.direction, p.state, p.note, p.verify_mode, p.attendance_id,
                    e.name AS employee_name, d.name AS device_name, d.serial_number,
                    du.device_name AS device_user_name
             FROM device_punches p
             LEFT JOIN employees e ON e.id = p.employee_id AND e.tenant_id = p.tenant_id
             LEFT JOIN attendance_devices d ON d.id = p.device_id
             LEFT JOIN device_users du ON du.device_id = p.device_id AND du.device_user_id = p.device_user_id
             WHERE " . implode(' AND ', $where) . "
             ORDER BY p.punched_at DESC
             LIMIT $limit",
            $params
        );
    }

    /** Counts by state for one device, for the status card in the app. */
    public static function statsForDevice(int $deviceId, int $tenantId): array {
        $rows = Database::fetchAll(
            "SELECT state, COUNT(*) AS c FROM device_punches
             WHERE device_id = ? AND tenant_id = ? GROUP BY state",
            [$deviceId, $tenantId]
        );
        $out = ['applied' => 0, 'unmatched' => 0, 'duplicate' => 0, 'ignored' => 0, 'failed' => 0];
        foreach ($rows as $r) {
            $out[$r['state']] = (int) $r['c'];
        }
        return $out;
    }

    /** Attaches the tenant to punches captured before the device was claimed. */
    public static function adoptOrphans(int $deviceId, int $tenantId): int {
        return Database::execute(
            "UPDATE device_punches SET tenant_id = ? WHERE device_id = ? AND tenant_id IS NULL",
            [$tenantId, $deviceId]
        );
    }
}
