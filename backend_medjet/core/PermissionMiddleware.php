<?php

final class PermissionMiddleware {
    private const PERMISSIONS = [
        'manage_employees',
        'manage_deduction_rules',
        'manage_attendance',
        'view_reports',
        'view_analytics',
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
        'manage_recruitment',
        'manage_performance',
        'manage_engagement',
        'manage_schedule',
        'manage_approvals',
    ];

    private const ROLE_DEFAULTS = [
        'general_manager' => '*',
        'hr' => ['manage_employees', 'manage_deduction_rules', 'manage_attendance', 'view_reports', 'view_analytics', 'manage_documents', 'manage_payroll', 'manage_leaves', 'manage_assets', 'manage_recruitment', 'manage_performance', 'manage_engagement', 'manage_schedule', 'manage_approvals', 'biometric_enroll', 'biometric_delete'],
        'branch_manager' => ['manage_employees', 'manage_attendance', 'manage_documents', 'view_reports', 'view_analytics', 'manage_assets', 'manage_recruitment', 'manage_performance', 'manage_engagement', 'manage_schedule', 'biometric_enroll'],
        'attendance' => ['manage_attendance', 'biometric_enroll'],
        'viewer' => ['view_reports', 'view_analytics'],
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

    /**
     * True when the caller may manage (edit / suspend / remove) the target —
     * i.e. the caller's access is equal-to-or-greater-than the target's. A
     * caller can never act on someone who is higher in the admin hierarchy,
     * meaning someone who holds a permission the caller lacks. '*' (general
     * manager) outranks everyone; only another '*' may manage a general manager.
     */
    public static function outranks(array|string $callerPerms, array|string $targetPerms): bool {
        if ($callerPerms === '*') {
            return true;
        }
        if ($targetPerms === '*') {
            return false;
        }
        return self::isWithin($targetPerms, $callerPerms);
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
