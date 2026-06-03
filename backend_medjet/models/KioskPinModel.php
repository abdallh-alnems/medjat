<?php

final class KioskPinModel {
    public static function generate(int $stationId, int $branchId, int $tenantId, int $adminId): array {
        $pin = '';
        for ($i = 0; $i < 6; $i++) {
            $pin .= random_int(0, 9);
        }

        $pinHash = password_hash($pin, PASSWORD_BCRYPT);
        $expiresAt = date('Y-m-d H:i:s', time() + 600);

        Database::execute(
            "INSERT INTO kiosk_pins (station_id, branch_id, tenant_id, pin_hash, expires_at, created_by)
             VALUES (?, ?, ?, ?, ?, ?)",
            [$stationId, $branchId, $tenantId, $pinHash, $expiresAt, $adminId]
        );

        $id = (int) Database::lastInsertId();

        return [
            'id' => $id,
            'pin' => $pin,
            'expires_at' => $expiresAt,
        ];
    }

    public static function verify(int $stationId, string $pin): bool {
        $row = Database::fetchOne(
            "SELECT id, pin_hash FROM kiosk_pins
             WHERE station_id = ? AND used_at IS NULL AND expires_at > NOW()
             ORDER BY created_at DESC LIMIT 1",
            [$stationId]
        );

        if (!$row) return false;

        if (!password_verify($pin, $row['pin_hash'])) return false;

        Database::execute(
            "UPDATE kiosk_pins SET used_at = NOW() WHERE id = ?",
            [(int) $row['id']]
        );

        return true;
    }

    public static function cleanup(): void {
        Database::execute(
            "DELETE FROM kiosk_pins WHERE expires_at < DATE_SUB(NOW(), INTERVAL 1 HOUR)"
        );
    }
}
