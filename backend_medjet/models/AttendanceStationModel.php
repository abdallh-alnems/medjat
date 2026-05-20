<?php

final class AttendanceStationModel {
    public static function createStation(int $branchId, int $tenantId, string $deviceName, int $createdBy, string $adminPin): array {
        $token = 'ST-' . bin2hex(random_bytes(32));
        $qrPayload = bin2hex(random_bytes(16));
        $qrExpires = date('Y-m-d H:i:s', strtotime('+24 hours'));
        $pinHash = password_hash($adminPin, PASSWORD_BCRYPT);

        Database::execute(
            "INSERT INTO attendance_stations (tenant_id, branch_id, device_token, device_name, activation_qr_payload, activation_qr_expires_at, created_by_user_id)
             VALUES (?, ?, ?, ?, ?, ?, ?)",
            [$tenantId, $branchId, $token, $deviceName, $qrPayload, $qrExpires, $createdBy]
        );

        $id = (int) Database::lastInsertId();

        $branch = BranchModel::findById($branchId, $tenantId);
        if ($branch && !$branch['station_admin_pin_hash']) {
            BranchModel::update($branchId, $tenantId, [
                'station_admin_pin_hash' => $pinHash,
                'station_enabled' => 1,
            ]);
        }

        return [
            'id' => $id,
            'device_token' => $token,
            'qr_payload' => $qrPayload,
            'expires_at' => $qrExpires,
        ];
    }

    public static function activateStation(string $qrPayload, array $deviceInfo): ?array {
        $station = Database::fetchOne(
            "SELECT s.*, b.station_methods, b.station_confidence_threshold,
                    b.station_gps_radius_meters, b.station_anti_spoofing_enabled,
                    b.latitude AS branch_lat, b.longitude AS branch_lng
             FROM attendance_stations s
             JOIN branches b ON b.id = s.branch_id
             WHERE s.activation_qr_payload = ? AND s.is_activated = 0 AND s.activation_qr_expires_at > NOW()
             LIMIT 1",
            [$qrPayload]
        );

        if (!$station) return null;

        Database::execute(
            "UPDATE attendance_stations SET is_activated = 1, activated_at = NOW() WHERE id = ?",
            [$station['id']]
        );

        $employees = BiometricModel::findEmployeesForBranch($station['branch_id'], $station['tenant_id']);

        return [
            'device_token' => $station['device_token'],
            'branch' => [
                'id' => $station['branch_id'],
                'name' => '',
                'lat' => $station['branch_lat'],
                'lng' => $station['branch_lng'],
            ],
            'settings' => [
                'methods' => $station['station_methods'],
                'confidence_threshold' => (float) $station['station_confidence_threshold'],
                'gps_radius_meters' => (int) $station['station_gps_radius_meters'],
                'anti_spoofing' => (bool) $station['station_anti_spoofing_enabled'],
            ],
            'employees' => $employees,
        ];
    }

    public static function findByToken(string $token): ?array {
        return Database::fetchOne(
            "SELECT s.*, b.station_methods, b.station_confidence_threshold,
                    b.station_gps_radius_meters, b.station_anti_spoofing_enabled,
                    b.station_admin_pin_hash
             FROM attendance_stations s
             JOIN branches b ON b.id = s.branch_id
             WHERE s.device_token = ? AND s.is_activated = 1 AND s.is_active = 1
             LIMIT 1",
            [$token]
        );
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT s.*, b.name AS branch_name
             FROM attendance_stations s
             JOIN branches b ON b.id = s.branch_id
             WHERE s.id = ? AND s.tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function getStationsByBranch(int $branchId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT s.*, b.name AS branch_name
             FROM attendance_stations s
             JOIN branches b ON b.id = s.branch_id
             WHERE s.branch_id = ? AND s.tenant_id = ?
             ORDER BY s.created_at DESC",
            [$branchId, $tenantId]
        );
    }

    public static function getAllStations(int $tenantId): array {
        return Database::fetchAll(
            "SELECT s.*, b.name AS branch_name
             FROM attendance_stations s
             JOIN branches b ON b.id = s.branch_id
             WHERE s.tenant_id = ?
             ORDER BY s.created_at DESC",
            [$tenantId]
        );
    }

    public static function updateStation(int $id, int $tenantId, array $data): void {
        $fields = [];
        $values = [];
        foreach ($data as $key => $value) {
            $fields[] = "{$key} = ?";
            $values[] = $value;
        }
        $values[] = $id;
        $values[] = $tenantId;
        Database::execute(
            "UPDATE attendance_stations SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    public static function regenerateQR(int $id, int $tenantId): ?array {
        $qrPayload = bin2hex(random_bytes(16));
        $qrExpires = date('Y-m-d H:i:s', strtotime('+24 hours'));
        Database::execute(
            "UPDATE attendance_stations SET activation_qr_payload = ?, activation_qr_expires_at = ?, is_activated = 0 WHERE id = ? AND tenant_id = ?",
            [$qrPayload, $qrExpires, $id, $tenantId]
        );
        return ['qr_payload' => $qrPayload, 'expires_at' => $qrExpires];
    }

    public static function deactivateStation(int $id, int $tenantId): bool {
        return Database::execute(
            "UPDATE attendance_stations SET is_active = 0, deactivated_at = NOW() WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }

    public static function lockStation(int $id, string $reason): void {
        Database::execute(
            "UPDATE attendance_stations SET is_locked = 1, locked_reason = ?, locked_at = NOW() WHERE id = ?",
            [$reason, $id]
        );
    }

    public static function unlockStation(int $id, int $tenantId): void {
        Database::execute(
            "UPDATE attendance_stations SET is_locked = 0, locked_reason = NULL, locked_at = NULL WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        );
    }

    public static function updateHeartbeat(int $id, ?float $lat, ?float $lng): void {
        Database::execute(
            "UPDATE attendance_stations SET last_heartbeat_at = NOW(), last_known_lat = ?, last_known_lng = ? WHERE id = ?",
            [$lat, $lng, $id]
        );
    }

    public static function verifyAdminPin(int $branchId, string $pin): bool {
        $branch = Database::fetchOne(
            "SELECT station_admin_pin_hash FROM branches WHERE id = ? LIMIT 1",
            [$branchId]
        );
        if (!$branch || !$branch['station_admin_pin_hash']) return false;
        return password_verify($pin, $branch['station_admin_pin_hash']);
    }

    public static function getSyncData(int $stationId, int $tenantId): array {
        $station = self::findById($stationId, $tenantId);
        if (!$station) return [];

        $employees = BiometricModel::findEmployeesForBranch($station['branch_id'], $tenantId);

        $branch = BranchModel::findById($station['branch_id'], $tenantId);

        return [
            'employees' => $employees,
            'settings' => [
                'methods' => $branch['station_methods'] ?? 'face_only',
                'confidence_threshold' => (float) ($branch['station_confidence_threshold'] ?? 0.85),
                'gps_radius_meters' => (int) ($branch['station_gps_radius_meters'] ?? 30),
                'anti_spoofing' => (bool) ($branch['station_anti_spoofing_enabled'] ?? true),
            ],
        ];
    }
}
