<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

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
    Response::fail('الدور غير صالح', 422, 'invalid_role');
}

// Optional custom permissions chosen by the inviter for this invitee.
$permissions = $input['permissions'] ?? null;
if ($permissions !== null) {
    if (!is_array($permissions)) {
        Response::fail('permissions must be an array', 422, 'permissions_array');
    }
    $validPerms = RoleModel::getAvailablePermissions();
    foreach ($permissions as $perm) {
        if (!in_array($perm, $validPerms, true)) {
            Response::fail("صلاحية غير معروفة: {$perm}", 422, 'unknown_permission');
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
    Response::fail('صيغة البريد الإلكتروني غير صحيحة', 422, 'invalid_email');
}

$existingAdmin = Database::fetchOne(
    "SELECT id, tenant_id FROM admins WHERE email = ? LIMIT 1",
    [$email]
);
// Unregistered emails are now allowed (market-standard "invite by email"): the
// invitation waits, and the person is linked when they sign up with the same
// email — surfaced on their onboarding screen. Only block someone who already
// belongs to a company.
if ($existingAdmin && $existingAdmin['tenant_id']) {
    Response::fail('هذا المستخدم ينتمي لشركة بالفعل', 409, 'user_already_in_company');
}

if ($branchId !== null) {
    $branch = Database::fetchOne(
        "SELECT id FROM branches WHERE id = ? AND tenant_id = ? LIMIT 1",
        [$branchId, $tenantId]
    );
    if (!$branch) Response::fail('الفرع غير موجود', 404, 'branch_not_found');
}

$existing = Database::fetchOne(
    "SELECT id FROM manager_invitations
     WHERE tenant_id = ? AND email = ?
        AND cancelled_at IS NULL AND accepted_at IS NULL AND expires_at > NOW()
     LIMIT 1",
    [$tenantId, $email]
);
if ($existing) {
    Response::fail('يوجد دعوة معلقة بالفعل لهذا البريد الإلكتروني', 409, 'invitation_already_pending');
}

$result = ManagerInvitationModel::create($tenantId, $auth['admin_id'], [
    'name' => $name,
    'email' => $email,
    'role' => $role,
    'branch_id' => $branchId,
    'permissions' => $permissions,
]);

AuditLogModel::log($tenantId, $auth['admin_id'], 'manager.invite', 'invitation', $result['id']);

// Email the invitee automatically (code + how to join) *after* the response is
// sent so the slow SMTP send never blocks the request. The code is still
// returned for in-person / QR sharing. Shared with the super-admin panel, which
// sends the identical message when it onboards a company.
$tenantRow = Database::fetchOne("SELECT name FROM tenants WHERE id = ? LIMIT 1", [$tenantId]);
ManagerInviteMailer::queue($email, $result['code'], $role, $tenantRow['name'] ?? '');

Response::success([
    'invitation_id' => $result['id'],
    'invitation_code' => $result['code'],
    'expires_at' => $result['expires_at'],
    'expires_in_hours' => 72,
], 201);
