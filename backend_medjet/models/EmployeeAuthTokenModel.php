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
