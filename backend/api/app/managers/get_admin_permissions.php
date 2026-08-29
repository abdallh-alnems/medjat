<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'add_managers');

$adminId = (int) ($_GET['admin_id'] ?? 0);
Validator::required($adminId, 'admin_id');

$admin = Database::fetchOne(
    "SELECT id, role FROM admins WHERE id = ? AND tenant_id = ? LIMIT 1",
    [$adminId, $tenantId]
);
if (!$admin) {
    Response::notFound('Admin');
}

$role = $admin['role'];
$roleDefaults = RoleModel::getRoleDefaults($role);
if ($roleDefaults === '*') {
    $roleDefaults = RoleModel::getAvailablePermissions();
}

$customPerms = RoleModel::getPermissions($adminId, $tenantId);
$isCustomized = $customPerms !== null;
$effectivePermissions = $isCustomized ? $customPerms : $roleDefaults;

Response::success([
    'admin_id' => $adminId,
    'role' => $role,
    'role_defaults' => $roleDefaults,
    'effective_permissions' => $effectivePermissions,
    'is_customized' => $isCustomized,
    'all_permissions' => RoleModel::getAvailablePermissions(),
]);
