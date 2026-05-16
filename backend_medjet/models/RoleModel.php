<?php

final class RoleModel {
    public static function getPermissions(int $userId, int $tenantId): ?array {
        $row = Database::fetchOne(
            "SELECT permissions FROM custom_roles WHERE user_id = ? AND tenant_id = ? LIMIT 1",
            [$userId, $tenantId]
        );
        if (!$row) return null;
        return json_decode($row['permissions'], true);
    }

    public static function create(int $tenantId, int $userId, string $name, array $permissions, ?int $branchId = null): int {
        Database::execute(
            "INSERT INTO custom_roles (tenant_id, user_id, branch_id, name, permissions) VALUES (?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE name = VALUES(name), permissions = VALUES(permissions), branch_id = VALUES(branch_id)",
            [$tenantId, $userId, $branchId, $name, json_encode($permissions)]
        );
        return (int) Database::lastInsertId();
    }

    public static function getByTenant(int $tenantId): array {
        return Database::fetchAll(
            "SELECT cr.*, u.name as user_name FROM custom_roles cr
             JOIN users u ON u.id = cr.user_id
             WHERE cr.tenant_id = ? ORDER BY cr.created_at DESC",
            [$tenantId]
        );
    }

    public static function getAvailablePermissions(): array {
        return [
            'manage_employees',
            'manage_deduction_rules',
            'manage_attendance',
            'view_reports',
            'manage_documents',
            'manage_payroll',
            'manage_leaves',
            'add_managers',
            'manage_company_settings',
        ];
    }
}
