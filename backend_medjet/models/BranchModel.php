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
            "SELECT b.*, (
                 SELECT COUNT(*) FROM employees e
                 WHERE e.branch_id = b.id
                   AND e.tenant_id = b.tenant_id
                   AND e.status != 'terminated'
             ) AS employee_count
             FROM branches b WHERE b.tenant_id = ? ORDER BY b.name ASC",
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

    /**
     * Ensure a branch has a QR payload, generating + persisting one if missing.
     * Returns the (existing or new) qr_code. Pass $force to regenerate.
     */
    public static function ensureQrCode(int $id, int $tenantId, bool $force = false): ?string {
        $branch = self::findById($id, $tenantId);
        if (!$branch) {
            return null;
        }
        if (!$force && !empty($branch['qr_code'])) {
            return $branch['qr_code'];
        }
        $code = self::generateQrCode();
        Database::execute(
            "UPDATE branches SET qr_code = ? WHERE id = ? AND tenant_id = ?",
            [$code, $id, $tenantId]
        );
        return $code;
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

    /**
     * Resolve the GPS geofence in effect for a branch: the branch's own
     * latitude/longitude when set, otherwise the company (tenant) default.
     * Returns ['lat'=>?float, 'lng'=>?float, 'radius'=>int]. lat/lng are null
     * when no center is configured anywhere (no geofence to enforce).
     */
    public static function effectiveGeofence(int $branchId, int $tenantId, bool $allowCompanyFallback = true): array {
        $branch = self::findById($branchId, $tenantId);
        // branches.latitude/longitude are NOT NULL; an unset branch reads as
        // 0,0 — treat that as "no branch center".
        $bLat = $branch !== null && $branch['latitude'] !== null ? (float) $branch['latitude'] : null;
        $bLng = $branch !== null && $branch['longitude'] !== null ? (float) $branch['longitude'] : null;
        if ($bLat !== null && $bLng !== null && !($bLat == 0.0 && $bLng == 0.0)) {
            return [
                'lat' => $bLat,
                'lng' => $bLng,
                'radius' => (int) ($branch['gps_radius_meters'] ?? 100),
            ];
        }
        // The branch has no center of its own. When validating a check-in we do
        // NOT fall back to the company center: with multiple branches that would
        // let an employee check into a branch they are nowhere near (e.g. the
        // Jeddah branch while standing at the head office). The fallback is only
        // for display/info contexts that explicitly opt in.
        if (!$allowCompanyFallback) {
            return [
                'lat' => null,
                'lng' => null,
                'radius' => (int) ($branch['gps_radius_meters'] ?? 100),
            ];
        }
        $tenant = TenantModel::findById($tenantId);
        if ($tenant && ($tenant['gps_latitude'] ?? null) !== null && ($tenant['gps_longitude'] ?? null) !== null) {
            return [
                'lat' => (float) $tenant['gps_latitude'],
                'lng' => (float) $tenant['gps_longitude'],
                'radius' => (int) ($tenant['gps_radius_meters'] ?? ($branch['gps_radius_meters'] ?? 100)),
            ];
        }
        return [
            'lat' => null,
            'lng' => null,
            'radius' => (int) ($branch['gps_radius_meters'] ?? 100),
        ];
    }

    /**
     * Resolve the attendance methods actually in effect for a branch: the
     * branch override when set, otherwise the company (tenant) default.
     * Always returns a non-empty list, defaulting to ['qr_gps'].
     */
    public static function effectiveMethods(int $branchId, int $tenantId): array {
        $branch = self::findById($branchId, $tenantId);
        if ($branch && $branch['attendance_methods'] !== null) {
            $methods = json_decode($branch['attendance_methods'], true);
            if (is_array($methods) && !empty($methods)) {
                return array_values($methods);
            }
        }
        $tenant = TenantModel::findById($tenantId);
        $methods = json_decode($tenant['attendance_methods'] ?? '["qr_gps"]', true);
        return (is_array($methods) && !empty($methods)) ? array_values($methods) : ['qr_gps'];
    }

}
