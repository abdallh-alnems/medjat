<?php

final class PermissionMiddleware {
    private const PERMISSIONS = [
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
        'manage_assets',
        'add_managers',
        'manage_company_settings',
        'manage_support',
    ];

    private const ROLE_DEFAULTS = [
        'general_manager' => '*',
        'hr' => ['manage_employees', 'manage_deduction_rules', 'manage_attendance', 'view_reports', 'manage_documents', 'manage_payroll', 'manage_leaves', 'manage_assets', 'biometric_enroll', 'biometric_delete', 'station_manage', 'station_view_logs'],
        'branch_manager' => ['manage_employees', 'manage_attendance', 'manage_documents', 'view_reports', 'manage_assets', 'biometric_enroll', 'station_view_logs'],
        'attendance' => ['manage_attendance', 'biometric_enroll', 'station_view_logs'],
        'viewer' => ['view_reports'],
        'employee' => [],
    ];

    /**
     * Passes when the user holds ANY of the given permissions (general_manager
     * and '*' always pass). Used for read-only lists several roles need, e.g.
     * dashboard filter dimensions.
     */
    public static function checkAny(array $user, array $permissions): void {
        $role = $user['role'] ?? '';

        if ($role === 'general_manager') {
            return;
        }

        $rolePerms = RoleModel::getPermissions($user['admin_id'], $user['tenant_id']);
        if ($rolePerms === null) {
            $rolePerms = self::ROLE_DEFAULTS[$role] ?? [];
        }

        if ($rolePerms === '*') {
            return;
        }

        foreach ($permissions as $perm) {
            if (in_array($perm, (array) $rolePerms, true)) {
                return;
            }
        }

        Response::forbidden('Missing permission: one of ' . implode(', ', $permissions));
    }

    public static function check(array $user, string $permission): void {
        $role = $user['role'] ?? '';

        if ($role === 'general_manager') {
            return;
        }

        $rolePerms = RoleModel::getPermissions($user['admin_id'], $user['tenant_id']);
        if ($rolePerms === null) {
            $rolePerms = self::ROLE_DEFAULTS[$role] ?? [];
        }

        if ($rolePerms === '*' || in_array($permission, (array) $rolePerms, true)) {
            return;
        }

        if (in_array('manage_documents', (array) $rolePerms, true)
            && in_array($permission, ['documents_manage_types', 'documents_verify', 'documents_view_reports'], true)) {
            return;
        }

        Response::forbidden("Missing permission: {$permission}");
    }

    /**
     * The effective permission set an admin currently holds.
     * Returns '*' for full access (general_manager), otherwise an array of
     * permission keys (custom role overrides the role defaults).
     */
    public static function effectivePermissions(int $adminId, int $tenantId, string $role): array|string {
        if ($role === 'general_manager') {
            return '*';
        }

        $custom = RoleModel::getPermissions($adminId, $tenantId);
        if ($custom !== null) {
            return $custom;
        }

        return self::ROLE_DEFAULTS[$role] ?? [];
    }

    /**
     * True when every permission in $granted is covered by $owner.
     * $owner === '*' covers everything. Used to enforce that an admin can
     * never grant a permission (or role) higher than their own.
     */
    public static function isWithin(array $granted, array|string $owner): bool {
        if ($owner === '*') {
            return true;
        }
        foreach ($granted as $perm) {
            if (!in_array($perm, $owner, true)) {
                return false;
            }
        }
        return true;
    }

    public static function checkBranchAccess(array $user, ?int $branchId): void {
        $role = $user['role'] ?? '';

        if ($role === 'general_manager' || $role === 'hr') {
            return;
        }

        if ($user['branch_id'] !== null && $branchId !== null && (int) $user['branch_id'] !== (int) $branchId) {
            Response::forbidden('Access denied for this branch');
        }
    }
}
