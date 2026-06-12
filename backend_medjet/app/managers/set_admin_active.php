<?php
// Activate or deactivate a team member (reversible — keeps their data and role).
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'add_managers');

$input = $auth['input'];
$adminId = (int) ($input['admin_id'] ?? 0);
Validator::required($adminId, 'admin_id');

$isActive = filter_var($input['is_active'] ?? null, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
if ($isActive === null) {
    Response::fail('is_active مطلوب', 422);
}

if ($adminId === (int) $auth['admin_id']) {
    Response::forbidden('لا يمكنك تعطيل حسابك بنفسك');
}

$admin = Database::fetchOne(
    "SELECT id, role FROM admins WHERE id = ? AND tenant_id = ? LIMIT 1",
    [$adminId, $tenantId]
);
if (!$admin) {
    Response::notFound('المدير');
}

$inviterPerms = PermissionMiddleware::effectivePermissions(
    $auth['admin_id'], $tenantId, $auth['role']
);
if ($admin['role'] === 'general_manager' && $inviterPerms !== '*') {
    Response::forbidden('لا يمكنك تعطيل مدير عام');
}

Database::execute(
    "UPDATE admins SET is_active = ? WHERE id = ? AND tenant_id = ?",
    [$isActive ? 1 : 0, $adminId, $tenantId]
);

AuditLogModel::log(
    $tenantId,
    $auth['admin_id'],
    $isActive ? 'admin.activated' : 'admin.deactivated',
    'admin',
    $adminId
);

Response::success([
    'message' => $isActive ? 'تم تفعيل المدير' : 'تم تعطيل المدير',
    'is_active' => $isActive,
]);
