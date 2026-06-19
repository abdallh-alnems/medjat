<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'add_managers');

$input = $auth['input'];
$adminId = (int) ($input['admin_id'] ?? 0);
Validator::required($adminId, 'admin_id');

$admin = Database::fetchOne(
    "SELECT id, role FROM admins WHERE id = ? AND tenant_id = ? LIMIT 1",
    [$adminId, $tenantId]
);
if (!$admin) {
    Response::notFound('Admin');
}

if ($admin['role'] === 'general_manager') {
    Response::forbidden('General manager permissions cannot be modified');
}

$permissions = $input['permissions'] ?? [];
if (!is_array($permissions)) {
    Response::fail('permissions must be an array', 400, 'permissions_array');
}

$validPerms = RoleModel::getAvailablePermissions();
foreach ($permissions as $perm) {
    if (!in_array($perm, $validPerms, true)) {
        Response::fail("Unknown permission: {$perm}", 400, 'unknown_permission');
    }
}

// Enforce equal-or-lower: cannot grant a permission you don't hold yourself.
$inviterPerms = PermissionMiddleware::effectivePermissions(
    $auth['admin_id'], $tenantId, $auth['role']
);
if (!PermissionMiddleware::isWithin($permissions, $inviterPerms)) {
    Response::forbidden('لا يمكنك منح صلاحيات لا تملكها');
}

Database::execute(
    "INSERT INTO custom_roles (tenant_id, admin_id, name, permissions)
     VALUES (?, ?, 'custom', ?)
     ON DUPLICATE KEY UPDATE permissions = VALUES(permissions), updated_at = CURRENT_TIMESTAMP",
    [$tenantId, $adminId, json_encode(array_values(array_unique($permissions)))]
);

AuditLogModel::log($tenantId, $auth['admin_id'], 'admin.permissions_updated', 'admin', $adminId, ['permissions' => $permissions]);

Response::success(['message' => 'Permissions updated']);
