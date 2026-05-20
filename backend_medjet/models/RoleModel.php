<?php

final class RoleModel {
    public static function getPermissions(int $adminId, int $tenantId): ?array {
        $row = Database::fetchOne(
            "SELECT permissions FROM custom_roles WHERE admin_id = ? AND tenant_id = ? LIMIT 1",
            [$adminId, $tenantId]
        );
        if (!$row) return null;
        return json_decode($row['permissions'], true);
    }

    public static function create(int $tenantId, int $adminId, string $name, array $permissions, ?int $branchId = null): int {
        Database::execute(
            "INSERT INTO custom_roles (tenant_id, admin_id, branch_id, name, permissions) VALUES (?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE name = VALUES(name), permissions = VALUES(permissions), branch_id = VALUES(branch_id)",
            [$tenantId, $adminId, $branchId, $name, json_encode($permissions)]
        );
        return (int) Database::lastInsertId();
    }

    public static function getByTenant(int $tenantId): array {
        return Database::fetchAll(
            "SELECT cr.*, a.name as admin_name FROM custom_roles cr
             JOIN admins a ON a.id = cr.admin_id
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
            'documents_manage_types',
            'documents_verify',
            'documents_view_reports',
            'manage_payroll',
            'manage_leaves',
            'add_managers',
            'manage_company_settings',
        ];
    }

    public static function getRoleDefaults(string $role): array|string {
        $defaults = [
            'general_manager' => '*',
            'hr' => ['manage_employees', 'manage_deduction_rules', 'manage_attendance', 'view_reports', 'manage_documents', 'manage_payroll', 'manage_leaves'],
            'branch_manager' => ['manage_employees', 'manage_attendance', 'manage_documents', 'view_reports'],
            'attendance' => ['manage_attendance'],
            'viewer' => ['view_reports'],
            'employee' => [],
        ];
        return $defaults[$role] ?? [];
    }
}
