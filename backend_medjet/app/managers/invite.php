<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'add_managers');

$input = $auth['input'];
$name = trim($input['name'] ?? '');
$email = trim($input['email'] ?? '');
$role = $input['role'] ?? '';
$branchId = isset($input['branch_id']) && $input['branch_id'] !== ''
    ? (int) $input['branch_id'] : null;

$validRoles = ['general_manager', 'hr', 'branch_manager', 'attendance', 'viewer'];
if (!in_array($role, $validRoles, true)) {
    Response::fail('الدور غير صالح', 422);
}

// Optional custom permissions chosen by the inviter for this invitee.
$permissions = $input['permissions'] ?? null;
if ($permissions !== null) {
    if (!is_array($permissions)) {
        Response::fail('permissions must be an array', 422);
    }
    $validPerms = RoleModel::getAvailablePermissions();
    foreach ($permissions as $perm) {
        if (!in_array($perm, $validPerms, true)) {
            Response::fail("صلاحية غير معروفة: {$perm}", 422);
        }
    }
    $permissions = array_values(array_unique($permissions));
}

// Enforce equal-or-lower: an admin can never grant access above their own.
$grantedPerms = ($role === 'general_manager')
    ? '*'
    : ($permissions ?? RoleModel::getRoleDefaults($role));
$inviterPerms = PermissionMiddleware::effectivePermissions(
    $auth['admin_id'], $tenantId, $auth['role']
);
if ($grantedPerms === '*') {
    if ($inviterPerms !== '*') {
        Response::forbidden('لا يمكنك منح صلاحيات أعلى من صلاحياتك');
    }
} elseif (!PermissionMiddleware::isWithin($grantedPerms, $inviterPerms)) {
    Response::forbidden('لا يمكنك منح صلاحيات لا تملكها');
}

Validator::required($email, 'البريد الإلكتروني');
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    Response::fail('صيغة البريد الإلكتروني غير صحيحة', 422);
}

$existingAdmin = Database::fetchOne(
    "SELECT id, tenant_id FROM admins WHERE email = ? LIMIT 1",
    [$email]
);
if (!$existingAdmin) {
    Response::fail('هذا البريد الإلكتروني غير مسجل في النظام. يجب التسجيل أولاً', 404);
}
if ($existingAdmin['tenant_id']) {
    Response::fail('هذا المستخدم ينتمي لشركة بالفعل', 409);
}

if ($branchId !== null) {
    $branch = Database::fetchOne(
        "SELECT id FROM branches WHERE id = ? AND tenant_id = ? LIMIT 1",
        [$branchId, $tenantId]
    );
    if (!$branch) Response::fail('الفرع غير موجود', 404);
}

$existing = Database::fetchOne(
    "SELECT id FROM manager_invitations
     WHERE tenant_id = ? AND email = ?
        AND cancelled_at IS NULL AND accepted_at IS NULL AND expires_at > NOW()
     LIMIT 1",
    [$tenantId, $email]
);
if ($existing) {
    Response::fail('يوجد دعوة معلقة بالفعل لهذا البريد الإلكتروني', 409);
}

$result = ManagerInvitationModel::create($tenantId, $auth['admin_id'], [
    'name' => $name,
    'email' => $email,
    'role' => $role,
    'branch_id' => $branchId,
    'permissions' => $permissions,
]);

AuditLogModel::log($tenantId, $auth['admin_id'], 'manager.invite', 'invitation', $result['id']);

Response::success([
    'invitation_id' => $result['id'],
    'invitation_code' => $result['code'],
    'expires_at' => $result['expires_at'],
    'expires_in_hours' => 72,
], 201);
