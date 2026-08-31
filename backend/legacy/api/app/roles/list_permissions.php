<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'view_reports');

$roles = RoleModel::getByTenant($tenantId);
$permissions = RoleModel::getAvailablePermissions();

Response::success([
    'custom_roles' => $roles,
    'available_permissions' => $permissions,
]);
