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

Database::execute(
    "DELETE FROM custom_roles WHERE tenant_id = ? AND admin_id = ?",
    [$tenantId, $adminId]
);

AuditLogModel::log($tenantId, $auth['admin_id'], 'admin.permissions_reset', 'admin', $adminId);

Response::success(['message' => 'Permissions reset to defaults']);
