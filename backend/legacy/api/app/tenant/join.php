<?php
// Join an existing company via an invitation code/token.
// Owner generates the invite from their dashboard (separate endpoint TBD).

require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true);
if (!$input) {
    $input = [];
}

$token = $input['token'] ?? null;
$inviteCode = trim($input['invite_code'] ?? '');

if (!$token) {
    Response::fail('Token is required', 400, 'token_required');
}
if ($inviteCode === '') {
    Response::fail('Invite code is required', 422, 'invite_code_required');
}

$verifiedToken = Auth::verifyFirebaseToken($token);
$uid = $verifiedToken->claims()->get('sub');

$admin = Database::fetchOne(
    "SELECT id, tenant_id, email, name FROM admins WHERE firebase_uid = ? LIMIT 1",
    [$uid]
);
if (!$admin) {
    Response::fail('Sign in first', 401, 'sign_first');
}
if ($admin['tenant_id']) {
    Response::fail('You already belong to a company', 409, 'you_already_belong_company');
}

$tokenHash = hash('sha256', $inviteCode);

$invitation = Database::fetchOne(
    "SELECT id, tenant_id, email, name, role, branch_id, permissions, expires_at, accepted_at, cancelled_at
     FROM manager_invitations
     WHERE token_hash = ? LIMIT 1",
    [$tokenHash]
);

if (!$invitation) {
    Response::fail('Invite code is invalid', 404, 'invite_code_invalid');
}
if ($invitation['cancelled_at']) {
    Response::fail('This invitation was cancelled', 410, 'invitation_was_cancelled');
}
if ($invitation['accepted_at']) {
    Response::fail('This invitation was already used', 410, 'invitation_was_already_used');
}
if (strtotime($invitation['expires_at']) < time()) {
    Response::fail('This invitation has expired', 410, 'invitation_expired');
}

if ($invitation['email'] && $admin['email'] && strcasecmp($invitation['email'], $admin['email']) !== 0) {
    Response::fail('This invitation is for a different email address', 403, 'invitation_different_email_address');
}

$pdo = db();
try {
    $pdo->beginTransaction();

    $stmt = $pdo->prepare(
        "UPDATE admins
         SET tenant_id = ?, branch_id = ?, role = ?, name = COALESCE(NULLIF(?, ''), name)
         WHERE id = ?"
    );
    $stmt->execute([
        $invitation['tenant_id'],
        $invitation['branch_id'],
        $invitation['role'],
        $invitation['name'],
        $admin['id'],
    ]);

    if ($invitation['permissions']) {
        $stmt = $pdo->prepare(
            "INSERT INTO custom_roles (tenant_id, admin_id, branch_id, name, permissions)
             VALUES (?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE permissions = VALUES(permissions), branch_id = VALUES(branch_id)"
        );
        $stmt->execute([
            $invitation['tenant_id'],
            $admin['id'],
            $invitation['branch_id'],
            $invitation['role'],
            $invitation['permissions'],
        ]);
    }

    $stmt = $pdo->prepare(
        "UPDATE manager_invitations
         SET accepted_at = NOW(), accepted_admin_id = ?
         WHERE id = ?"
    );
    $stmt->execute([$admin['id'], $invitation['id']]);

    $stmt = $pdo->prepare(
        "INSERT INTO audit_log (tenant_id, admin_id, action, target_type, target_id, ip)
         VALUES (?, ?, 'invitation.accepted', 'invitation', ?, ?)"
    );
    $stmt->execute([
        $invitation['tenant_id'],
        $admin['id'],
        $invitation['id'],
        $_SERVER['REMOTE_ADDR'] ?? '',
    ]);

    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log('Join tenant failed: ' . $e->getMessage());
    Response::fail('Failed to join company: ' . $e->getMessage(), 500, 'join_company_failed');
}

$tenant = Database::fetchOne(
    "SELECT id, name, currency, timezone FROM tenants WHERE id = ? LIMIT 1",
    [(int) $invitation['tenant_id']]
);

Response::success([
    'success' => true,
    'tenant' => $tenant ? [
        'id' => (int) $tenant['id'],
        'name' => $tenant['name'],
        'currency' => $tenant['currency'],
        'timezone' => $tenant['timezone'],
    ] : null,
    'user' => [
        'id' => (int) $admin['id'],
        'tenant_id' => (int) $invitation['tenant_id'],
        'role' => $invitation['role'],
        'role_key' => $invitation['role'],
        'branch_id' => $invitation['branch_id'] ? (int) $invitation['branch_id'] : null,
    ],
]);
