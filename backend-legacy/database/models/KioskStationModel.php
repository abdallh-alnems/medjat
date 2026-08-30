<?php

/**
 * A tablet in service at one branch.
 *
 * Revocation is a state, never a delete: `attendance.station_id` points here,
 * and historical attendance must keep resolving to the device that recorded it
 * long after that device has been retired.
 */
final class KioskStationModel {
    public static function create(
        int $tenantId,
        int $branchId,
        ?string $name,
        ?string $deviceModel,
        string $platform,
        ?string $appVersion,
        ?int $pairedBy
    ): int {
        Database::execute(
            "INSERT INTO attendance_stations
                (tenant_id, branch_id, name, device_model, platform, app_version,
                 paired_by, paired_at, last_seen_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())",
            [$tenantId, $branchId, $name, $deviceModel, $platform, $appVersion, $pairedBy]
        );

        return (int) Database::lastInsertId();
    }

    public static function findById(int $stationId, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM attendance_stations WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$stationId, $tenantId]
        );
    }

    /**
     * The fleet, for the management app.
     *
     * `is_offline` is decided here rather than in the client so that every
     * surface agrees on what "dark" means. Thirty minutes is deliberately
     * generous: a kiosk heartbeats often, and a brief network blip at a branch
     * should not page anybody.
     */
    public static function listForTenant(int $tenantId, ?int $branchId = null): array {
        $sql = "SELECT s.*, b.name AS branch_name,
                       (s.last_seen_at IS NULL OR s.last_seen_at < DATE_SUB(NOW(), INTERVAL 30 MINUTE)) AS is_offline
                  FROM attendance_stations s
                  JOIN branches b ON b.id = s.branch_id
                 WHERE s.tenant_id = ?";
        $params = [$tenantId];

        if ($branchId !== null) {
            $sql .= " AND s.branch_id = ?";
            $params[] = $branchId;
        }

        return Database::fetchAll($sql . " ORDER BY b.name, s.name", $params);
    }

    /**
     * Every kiosk that has not been seen recently during a working day.
     *
     * Feeds the dark-kiosk alert: a branch whose tablet died at 6 a.m. has no
     * way to clock anybody in, and nobody notices until people complain.
     */
    public static function findDark(int $staleMinutes = 30): array {
        return Database::fetchAll(
            "SELECT s.*, b.name AS branch_name, t.timezone
               FROM attendance_stations s
               JOIN branches b ON b.id = s.branch_id
               JOIN tenants  t ON t.id = s.tenant_id
              WHERE s.status = 'active'
                AND (s.last_seen_at IS NULL
                     OR s.last_seen_at < DATE_SUB(NOW(), INTERVAL ? MINUTE))",
            [$staleMinutes]
        );
    }

    /** Called on every authenticated request, so it stays a single cheap write. */
    public static function touchSeen(int $stationId, ?string $ip, ?string $appVersion): void {
        Database::execute(
            "UPDATE attendance_stations
                SET last_seen_at = NOW(),
                    last_ip = COALESCE(?, last_ip),
                    app_version = COALESCE(?, app_version)
              WHERE id = ?",
            [$ip, $appVersion, $stationId]
        );
    }

    public static function recordPunch(int $stationId): void {
        Database::execute(
            "UPDATE attendance_stations
                SET punch_count = punch_count + 1, last_punch_at = NOW()
              WHERE id = ?",
            [$stationId]
        );
    }

    public static function revoke(int $stationId, int $tenantId, ?int $revokedBy): bool {
        $affected = Database::execute(
            "UPDATE attendance_stations
                SET status = 'revoked', revoked_at = NOW(), revoked_by = ?
              WHERE id = ? AND tenant_id = ? AND status = 'active'",
            [$revokedBy, $stationId, $tenantId]
        );

        if ($affected > 0) {
            KioskTokenModel::revokeForStation($stationId, 'unpaired');
            return true;
        }
        return false;
    }
}
