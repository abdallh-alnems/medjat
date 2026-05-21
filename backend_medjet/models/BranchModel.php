<?php

final class BranchModel {
    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM branches WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function getAll(int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM branches WHERE tenant_id = ? ORDER BY name ASC",
            [$tenantId]
        );
    }

    public static function create(int $tenantId, array $data): int {
        Database::execute(
            "INSERT INTO branches (tenant_id, name, address, latitude, longitude, qr_code)
             VALUES (?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $data['name'],
                $data['address'] ?? null,
                $data['latitude'] ?? 0,
                $data['longitude'] ?? 0,
                $data['qr_code'] ?? self::generateQrCode(),
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function update(int $id, int $tenantId, array $data): void {
        $fields = [];
        $values = [];
        foreach ($data as $key => $value) {
            $fields[] = "{$key} = ?";
            $values[] = $value;
        }
        $values[] = $id;
        $values[] = $tenantId;
        Database::execute(
            "UPDATE branches SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    public static function delete(int $id, int $tenantId): bool {
        return Database::execute(
            "DELETE FROM branches WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }

    public static function getEmployeeCount(int $branchId, int $tenantId): int {
        $row = Database::fetchOne(
            "SELECT COUNT(*) as count FROM employees WHERE branch_id = ? AND tenant_id = ?",
            [$branchId, $tenantId]
        );
        return (int) ($row['count'] ?? 0);
    }

    private static function generateQrCode(): string {
        return 'MED-' . strtoupper(bin2hex(random_bytes(8)));
    }

    public static function updateAttendanceMethods(int $id, int $tenantId, ?array $methods, int $gpsRadiusMeters = 100, ?bool $allowOffline = null): void {
        $sql = "UPDATE branches SET attendance_methods = ?, gps_radius_meters = ?";
        $params = [$methods !== null ? json_encode($methods) : null, $gpsRadiusMeters];

        if ($allowOffline !== null) {
            $sql .= ", allow_offline_attendance = ?";
            $params[] = (int) $allowOffline;
        }

        $sql .= " WHERE id = ? AND tenant_id = ?";
        $params[] = $id;
        $params[] = $tenantId;

        Database::execute($sql, $params);
    }

    public static function effectiveAllowOffline(int $branchId, int $tenantId): bool {
        $branch = self::findById($branchId, $tenantId);
        if ($branch && $branch['allow_offline_attendance'] !== null) {
            return (bool) $branch['allow_offline_attendance'];
        }
        $tenant = TenantModel::findById($tenantId);
        return (bool) ($tenant['allow_offline_attendance'] ?? true);
    }

    public static function updateStationSettings(int $id, int $tenantId, array $data): void {
        $fields = [];
        $values = [];
        $allowed = ['station_enabled', 'station_methods', 'station_gps_radius_meters', 'station_confidence_threshold', 'station_admin_pin_hash', 'station_anti_spoofing_enabled'];
        foreach ($data as $key => $value) {
            if (in_array($key, $allowed, true)) {
                $fields[] = "{$key} = ?";
                $values[] = $value;
            }
        }
        if (empty($fields)) return;
        $values[] = $id;
        $values[] = $tenantId;
        Database::execute(
            "UPDATE branches SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }
}
