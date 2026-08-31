<?php

final class TenantModel {
    public static function findById(int $id): ?array {
        return Database::fetchOne(
            "SELECT * FROM tenants WHERE id = ? LIMIT 1",
            [$id]
        );
    }

    public static function create(array $data): int {
        Database::execute(
            "INSERT INTO tenants (name, is_active)
             VALUES (?, 1)",
            [
                $data['name'],
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function update(int $id, array $data): void {
        $fields = [];
        $values = [];
        foreach ($data as $key => $value) {
            $fields[] = "{$key} = ?";
            $values[] = $value;
        }
        $values[] = $id;
        Database::execute(
            "UPDATE tenants SET " . implode(', ', $fields) . " WHERE id = ?",
            $values
        );
    }

    public static function activate(int $id): void {
        Database::execute("UPDATE tenants SET is_active = 1 WHERE id = ?", [$id]);
    }

    public static function deactivate(int $id): void {
        Database::execute("UPDATE tenants SET is_active = 0 WHERE id = ?", [$id]);
    }

    public static function getAll(int $page = 1, int $limit = 20): array {
        $offset = ($page - 1) * $limit;
        $items = Database::fetchAll(
            "SELECT * FROM tenants ORDER BY created_at DESC LIMIT ? OFFSET ?",
            [$limit, $offset]
        );
        $total = Database::fetchOne("SELECT COUNT(*) as count FROM tenants")['count'];
        return ['items' => $items, 'total' => (int) $total, 'page' => $page];
    }

    public static function getEmployeeCount(int $tenantId): int {
        $row = Database::fetchOne(
            "SELECT COUNT(*) as count FROM employees WHERE tenant_id = ?",
            [$tenantId]
        );
        return (int) ($row['count'] ?? 0);
    }

    public static function getBranchCount(int $tenantId): int {
        $row = Database::fetchOne(
            "SELECT COUNT(*) as count FROM branches WHERE tenant_id = ?",
            [$tenantId]
        );
        return (int) ($row['count'] ?? 0);
    }

    public static function updateAttendanceMethods(int $id, array $methods, ?array $adminIds): void {
        Database::execute(
            "UPDATE tenants SET attendance_methods = ?, manual_attendance_admin_ids = ? WHERE id = ?",
            [json_encode($methods), $adminIds !== null ? json_encode($adminIds) : null, $id]
        );
    }

    /**
     * Company-wide face-recognition settings (the defaults every branch
     * inherits when it has no override of its own).
     */
    public static function updateFaceSettings(int $id, float $threshold, bool $livenessRequired, string $enforceMode): void {
        Database::execute(
            "UPDATE tenants SET face_match_threshold = ?, face_liveness_required = ?, face_enforce_mode = ? WHERE id = ?",
            [$threshold, (int) $livenessRequired, $enforceMode, $id]
        );
    }

    public static function updateAllowOffline(int $id, bool $allow): void {
        Database::execute(
            "UPDATE tenants SET allow_offline_attendance = ? WHERE id = ?",
            [(int) $allow, $id]
        );
    }

    public static function updateRejectMockLocation(int $id, bool $reject): void {
        Database::execute(
            "UPDATE tenants SET reject_mock_location = ? WHERE id = ?",
            [(int) $reject, $id]
        );
    }

    public static function updateRequireLocalBiometric(int $id, bool $require): void {
        Database::execute(
            "UPDATE tenants SET require_local_biometric = ? WHERE id = ?",
            [(int) $require, $id]
        );
    }

    /**
     * Whether this company rejects check-ins from a device reporting a mocked
     * GPS location. Off by default, so a company that never opted in keeps the
     * previous behaviour.
     */
    public static function rejectsMockLocation(int $id): bool {
        $row = Database::fetchOne(
            "SELECT reject_mock_location FROM tenants WHERE id = ? LIMIT 1",
            [$id]
        );
        return $row !== null && (int) $row['reject_mock_location'] === 1;
    }

    /**
     * Whether self check-in/out must be confirmed with the phone's own
     * fingerprint/FaceID. Opt-in per company; see
     * migrations/2026_07_31_local_biometric_gate.sql for what it does and does
     * not prove.
     */
    public static function requiresLocalBiometric(int $id): bool {
        $row = Database::fetchOne(
            "SELECT require_local_biometric FROM tenants WHERE id = ? LIMIT 1",
            [$id]
        );
        return $row !== null && (int) $row['require_local_biometric'] === 1;
    }

    /** Company-wide GPS geofence center + radius (the default for all branches). */
    public static function updateGeofence(int $id, ?float $lat, ?float $lng, ?int $radius): void {
        Database::execute(
            "UPDATE tenants SET gps_latitude = ?, gps_longitude = ?, gps_radius_meters = ? WHERE id = ?",
            [$lat, $lng, $radius, $id]
        );
    }

    public static function getAttendanceConfig(int $id): array {
        $row = Database::fetchOne(
            "SELECT attendance_methods, manual_attendance_admin_ids FROM tenants WHERE id = ? LIMIT 1",
            [$id]
        );
        if (!$row) {
            return ['methods' => ['qr_gps'], 'admin_ids' => null];
        }
        $methods = json_decode($row['attendance_methods'], true) ?: ['qr_gps'];
        $adminIds = $row['manual_attendance_admin_ids'] !== null
            ? json_decode($row['manual_attendance_admin_ids'], true)
            : null;
        return ['methods' => $methods, 'admin_ids' => $adminIds];
    }
}
