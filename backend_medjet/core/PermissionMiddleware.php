<?php

final class PermissionMiddleware {
    private const PERMISSIONS = [
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

    private const ROLE_DEFAULTS = [
        'owner' => '*',
        'hr' => ['manage_employees', 'manage_deduction_rules', 'manage_attendance', 'view_reports', 'manage_documents', 'manage_payroll', 'manage_leaves'],
        'branch_manager' => ['manage_employees', 'manage_attendance', 'manage_documents', 'view_reports'],
        'attendance' => ['manage_attendance'],
        'viewer' => ['view_reports'],
        'employee' => [],
    ];

    public static function check(array $user, string $permission): void {
        $role = $user['role'] ?? '';

        if ($role === 'owner') {
            return;
        }

        $rolePerms = RoleModel::getPermissions($user['admin_id'], $user['tenant_id']);
        if ($rolePerms === null) {
            $rolePerms = self::ROLE_DEFAULTS[$role] ?? [];
        }

        if ($rolePerms === '*' || in_array($permission, (array) $rolePerms, true)) {
            return;
        }

        Response::forbidden("Missing permission: {$permission}");
    }

    public static function checkBranchAccess(array $user, ?int $branchId): void {
        $role = $user['role'] ?? '';

        if ($role === 'owner' || $role === 'hr') {
            return;
        }

        if ($user['branch_id'] !== null && $branchId !== null && (int) $user['branch_id'] !== (int) $branchId) {
            Response::forbidden('Access denied for this branch');
        }
    }
}
