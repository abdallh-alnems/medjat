<?php

final class EmployeeAuthTokenModel {
    public static function findActiveForEmployee(int $employeeId): ?array {
        return Database::fetchOne(
            "SELECT id, tenant_id, employee_id, device_id, device_model, platform,
                    app_version, issued_at, last_used_at
             FROM employee_auth_tokens
             WHERE employee_id = ? AND revoked_at IS NULL
             LIMIT 1",
            [$employeeId]
        );
    }

    public static function issue(int $tenantId, int $employeeId, string $deviceId, ?string $deviceModel, string $platform, ?string $appVersion): string {
        self::revokeForEmployee($employeeId, 'reissued_on_login');

        $plain = bin2hex(random_bytes(32));
        $hash = hash('sha256', $plain);

        Database::execute(
            "INSERT INTO employee_auth_tokens (tenant_id, employee_id, token_hash, device_id, device_model, platform, app_version)
             VALUES (?, ?, ?, ?, ?, ?, ?)",
            [$tenantId, $employeeId, $hash, $deviceId, $deviceModel, $platform, $appVersion]
        );

        return $plain;
    }

    public static function findActiveByPlain(string $plain): ?array {
        $hash = hash('sha256', $plain);
        $row = Database::fetchOne(
            "SELECT id, tenant_id, employee_id, device_id, platform
             FROM employee_auth_tokens
             WHERE token_hash = ? AND revoked_at IS NULL
             LIMIT 1",
            [$hash]
        );

        if ($row) {
            Database::execute(
                "UPDATE employee_auth_tokens SET last_used_at = NOW() WHERE id = ?",
                [$row['id']]
            );
        }

        return $row;
    }

    public static function revokeByPlain(string $plain, string $reason): void {
        $hash = hash('sha256', $plain);
        Database::execute(
            "UPDATE employee_auth_tokens
             SET revoked_at = NOW(), revoke_reason = ?
             WHERE token_hash = ? AND revoked_at IS NULL",
            [$reason, $hash]
        );
    }

    public static function revokeForEmployee(int $employeeId, string $reason): ?int {
        $active = self::findActiveForEmployee($employeeId);
        if (!$active) {
            return null;
        }

        Database::execute(
            "UPDATE employee_auth_tokens
             SET revoked_at = NOW(), revoke_reason = ?
             WHERE id = ?",
            [$reason, $active['id']]
        );

        return (int) $active['id'];
    }
}
