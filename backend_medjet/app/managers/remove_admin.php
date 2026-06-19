<?php
// Remove a team member from the company (detaches them; frees their email
// to join another company). Their account itself is preserved.
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'add_managers');

$input = $auth['input'];
$adminId = (int) ($input['admin_id'] ?? 0);
Validator::required($adminId, 'admin_id');

if ($adminId === (int) $auth['admin_id']) {
    Response::forbidden('لا يمكنك إزالة نفسك من الفريق');
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
    Response::forbidden('لا يمكنك إزالة مدير عام');
}

// Never let the company lose its last general manager.
if ($admin['role'] === 'general_manager') {
    $gmCount = Database::fetchOne(
        "SELECT COUNT(*) AS c FROM admins
         WHERE tenant_id = ? AND role = 'general_manager' AND is_active = 1",
        [$tenantId]
    );
    if ((int) ($gmCount['c'] ?? 0) <= 1) {
        Response::fail('لا يمكن إزالة آخر مدير عام للشركة', 409, 'cannot_remove_last_owner');
    }
}

$pdo = db();
try {
    $pdo->beginTransaction();

    $stmt = $pdo->prepare(
        "UPDATE admins SET tenant_id = NULL, branch_id = NULL, is_active = 0
         WHERE id = ? AND tenant_id = ?"
    );
    $stmt->execute([$adminId, $tenantId]);

    $stmt = $pdo->prepare(
        "DELETE FROM custom_roles WHERE admin_id = ? AND tenant_id = ?"
    );
    $stmt->execute([$adminId, $tenantId]);

    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log('Remove admin failed: ' . $e->getMessage());
    Response::fail('تعذّر إزالة المدير', 500, 'remove_admin_failed');
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'admin.removed', 'admin', $adminId);

Response::success(['message' => 'تمت إزالة المدير من الفريق']);
