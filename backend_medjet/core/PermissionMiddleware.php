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
    ];

    private const ROLE_DEFAULTS = [
        'general_manager' => '*',
        'hr' => ['manage_employees', 'manage_deduction_rules', 'manage_attendance', 'view_reports', 'manage_documents', 'manage_payroll', 'manage_leaves', 'manage_assets', 'biometric_enroll', 'biometric_delete', 'station_manage', 'station_view_logs'],
        'branch_manager' => ['manage_employees', 'manage_attendance', 'manage_documents', 'view_reports', 'manage_assets', 'biometric_enroll', 'station_view_logs'],
        'attendance' => ['manage_attendance', 'biometric_enroll', 'station_view_logs'],
        'viewer' => ['view_reports'],
        'employee' => [],
    ];

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
