<?php
// Change an existing team member's role and/or branch.
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
    Response::forbidden('لا يمكنك تعديل دورك أو فرعك بنفسك');
}

$admin = Database::fetchOne(
    "SELECT id, role FROM admins WHERE id = ? AND tenant_id = ? LIMIT 1",
    [$adminId, $tenantId]
);
if (!$admin) {
    Response::notFound('المدير');
}

$newRole = array_key_exists('role', $input) ? trim((string) $input['role']) : null;
$hasBranch = array_key_exists('branch_id', $input);
$newBranchId = null;
if ($hasBranch) {
    $newBranchId = ($input['branch_id'] === '' || $input['branch_id'] === null)
        ? null : (int) $input['branch_id'];
}

if ($newRole === null && !$hasBranch) {
    Response::fail('لا يوجد تغييرات', 422);
}

$inviterPerms = PermissionMiddleware::effectivePermissions(
    $auth['admin_id'], $tenantId, $auth['role']
);

// Only a full-access admin may touch a general manager.
if ($admin['role'] === 'general_manager' && $inviterPerms !== '*') {
    Response::forbidden('لا يمكنك تعديل مدير عام');
}

$roleChanged = false;
if ($newRole !== null && $newRole !== $admin['role']) {
    $validRoles = ['general_manager', 'hr', 'branch_manager', 'attendance', 'viewer'];
    if (!in_array($newRole, $validRoles, true)) {
        Response::fail('الدور غير صالح', 422);
    }

    // Enforce equal-or-lower: cannot grant a role above your own access.
    $grantedPerms = ($newRole === 'general_manager')
        ? '*' : RoleModel::getRoleDefaults($newRole);
    if ($grantedPerms === '*') {
        if ($inviterPerms !== '*') {
            Response::forbidden('لا يمكنك منح صلاحيات أعلى من صلاحياتك');
        }
    } elseif (!PermissionMiddleware::isWithin($grantedPerms, $inviterPerms)) {
        Response::forbidden('لا يمكنك منح صلاحيات لا تملكها');
    }
    $roleChanged = true;
}

if ($hasBranch && $newBranchId !== null) {
    $branch = Database::fetchOne(
        "SELECT id FROM branches WHERE id = ? AND tenant_id = ? LIMIT 1",
        [$newBranchId, $tenantId]
    );
    if (!$branch) Response::fail('الفرع غير موجود', 404);
}

$sets = [];
$params = [];
if ($roleChanged) {
    $sets[] = 'role = ?';
    $params[] = $newRole;
}
if ($hasBranch) {
    $sets[] = 'branch_id = ?';
    $params[] = $newBranchId;
}

if ($sets) {
    $params[] = $adminId;
    $params[] = $tenantId;
    Database::execute(
        "UPDATE admins SET " . implode(', ', $sets) . " WHERE id = ? AND tenant_id = ?",
        $params
    );
}

// Role change invalidates any custom permission set (built on the old role).
if ($roleChanged) {
    Database::execute(
        "DELETE FROM custom_roles WHERE admin_id = ? AND tenant_id = ?",
        [$adminId, $tenantId]
    );
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'admin.updated', 'admin', $adminId, [
    'role' => $roleChanged ? $newRole : null,
    'branch_id' => $hasBranch ? $newBranchId : null,
]);

Response::success(['message' => 'تم تحديث بيانات المدير']);
