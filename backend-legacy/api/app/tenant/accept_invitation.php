<?php
// Accept a pending invitation that was sent to the signed-in user's email —
// no code required (the email match + authenticated session are the proof).
// Powers the one-tap "Join {company}" surfaced on the onboarding screen.

require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true);
if (!$input) {
    $input = [];
}

// Accept the Firebase token from the body (mobile app) or the X-Firebase-Token
// header (web) — mirrors how the app vs. web clients send it.
$token = $input['token']
    ?? $_SERVER['HTTP_X_FIREBASE_TOKEN']
    ?? $_GET['token']
    ?? null;
if (!$token) {
    Response::fail('Token is required', 400, 'token_required');
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
if (empty($admin['email'])) {
    Response::fail('No invitation found', 404, 'no_pending_invitation');
}

// Optional: caller can pin a specific invitation; otherwise take the most recent
// valid one addressed to this email.
$invitationId = isset($input['invitation_id']) ? (int) $input['invitation_id'] : 0;

$sql = "SELECT id, tenant_id, email, name, role, branch_id, permissions
        FROM manager_invitations
        WHERE email = ? AND cancelled_at IS NULL AND accepted_at IS NULL
          AND expires_at > NOW()";
$params = [$admin['email']];
if ($invitationId > 0) {
    $sql .= " AND id = ?";
    $params[] = $invitationId;
}
$sql .= " ORDER BY created_at DESC LIMIT 1";

$invitation = Database::fetchOne($sql, $params);
if (!$invitation) {
    Response::fail('لا توجد دعوة صالحة لهذا الحساب', 404, 'no_pending_invitation');
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
        "UPDATE manager_invitations SET accepted_at = NOW(), accepted_admin_id = ? WHERE id = ?"
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
    error_log('Accept invitation failed: ' . $e->getMessage());
    Response::fail('تعذّر الانضمام إلى الشركة', 500, 'join_company_failed');
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
