<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true);
if (!$input) {
    $input = [];
}

$token = $input['token'] ?? null;
if (!$token) {
    Response::fail('Token is required', 400, 'token_required');
}

$verifiedToken = Auth::verifyFirebaseToken($token);
$uid = $verifiedToken->claims()->get('sub');
$email = $verifiedToken->claims()->get('email');
$nameClaim = $verifiedToken->claims()->get('name');
$displayName = is_string($nameClaim) ? trim($nameClaim) : '';
if ($displayName === '' && $email) {
    $displayName = strtok($email, '@');
}

$admin = Database::fetchOne(
    "SELECT id, firebase_uid, tenant_id, branch_id, name, phone, email, role, is_active
     FROM admins
     WHERE firebase_uid = ?" . ($email ? " OR email = ?" : "") . " LIMIT 1",
    $email ? [$uid, $email] : [$uid]
);

if (!$admin) {
    Database::execute(
        "INSERT INTO admins (firebase_uid, name, email, auth_provider, role, is_active, email_verified_at, last_login_at)
         VALUES (?, ?, ?, 'google', 'pending', 1, NOW(), NOW())",
        [$uid, $displayName ?: 'Admin', $email]
    );
    $adminId = (int) Database::lastInsertId();

    $admin = [
        'id' => $adminId,
        'firebase_uid' => $uid,
        'tenant_id' => null,
        'branch_id' => null,
        'name' => $displayName ?: 'Admin',
        'phone' => null,
        'email' => $email,
        'role' => 'pending',
        'is_active' => 1,
    ];
} else {
    if (empty($admin['firebase_uid'])) {
        Database::execute(
            "UPDATE admins SET firebase_uid = ? WHERE id = ?",
            [$uid, $admin['id']]
        );
        $admin['firebase_uid'] = $uid;
    }

    if (!$admin['is_active']) {
        if (empty($admin['tenant_id'])) {
            Response::fail('تمت إزالتك من الشركة من قِبل المسؤول', 403, 'account_removed');
        }
        Response::fail('تم إيقاف حسابك من قِبل المسؤول', 403, 'account_deactivated');
    }

    Database::execute(
        "UPDATE admins SET last_login_at = NOW(), last_login_ip = ? WHERE id = ?",
        [$_SERVER['REMOTE_ADDR'] ?? '', $admin['id']]
    );
}

// Single active session: the device that just logged in becomes the only
// active device. Any other phone is signed out on its next request
// (enforced in Auth::authenticateUser).
$deviceId = $_SERVER['HTTP_X_DEVICE_ID'] ?? ($input['device_id'] ?? null);
if (is_string($deviceId) && $deviceId !== '') {
    Database::execute(
        "UPDATE admins SET active_device_id = ? WHERE id = ?",
        [substr($deviceId, 0, 100), $admin['id']]
    );
}

$tenant = null;
$employee = null;
$pendingInvitation = null;
if ($admin['tenant_id']) {
    $tenant = Database::fetchOne(
        "SELECT id, name, currency, timezone FROM tenants WHERE id = ? LIMIT 1",
        [(int) $admin['tenant_id']]
    );
    $employee = EmployeeModel::findByAdminId((int) $admin['id'], (int) $admin['tenant_id']);
} elseif (!empty($admin['email'])) {
    // No company yet: if someone invited this email, surface it so onboarding
    // can offer a one-tap "Join {company}" instead of asking for the code.
    $inv = Database::fetchOne(
        "SELECT mi.id, mi.role, mi.expires_at, t.name AS company_name, b.name AS branch_name
         FROM manager_invitations mi
         JOIN tenants t ON t.id = mi.tenant_id
         LEFT JOIN branches b ON b.id = mi.branch_id
         WHERE mi.email = ? AND mi.cancelled_at IS NULL AND mi.accepted_at IS NULL
           AND mi.expires_at > NOW() AND t.is_active = 1
         ORDER BY mi.created_at DESC LIMIT 1",
        [$admin['email']]
    );
    if ($inv) {
        $pendingInvitation = [
            'invitation_id' => (int) $inv['id'],
            'company_name'  => $inv['company_name'],
            'role'          => $inv['role'],
            'role_key'      => $inv['role'],
            'branch_name'   => $inv['branch_name'],
            'expires_at'    => $inv['expires_at'],
        ];
    }
}

Database::execute(
    "INSERT INTO login_attempts (identifier, identifier_type, tenant_id, admin_id, success, ip, user_agent)
     VALUES (?, 'email', ?, ?, 1, ?, ?)",
    [
        $admin['email'] ?? '',
        $admin['tenant_id'] ? (int) $admin['tenant_id'] : null,
        (int) $admin['id'],
        $_SERVER['REMOTE_ADDR'] ?? '',
        substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 255),
    ]
);

// Fire the new-device alert (in-app notification, FCM push, email) *after* the
// response is sent. These are slow network calls — chiefly the SMTP send — and
// must never sit on the login critical path. See Background.
$alertIp = $_SERVER['REMOTE_ADDR'] ?? '';
$alertUa = substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 255);
Background::defer(static function () use ($admin, $alertIp, $alertUa) {
    LoginAlertService::handle($admin, $alertIp, $alertUa);
});

// The client gates its navigation (bottom tabs, "more" menu) on these. Send
// the *effective* set so permission-based roles (viewer, attendance, custom
// roles) see only what they can actually open — otherwise every gated tab
// falls through to a backend 403 ("an error occurred"). general_manager holds
// '*' and is already handled by role_key on the client, so send [] for it.
$effectivePermissions = PermissionMiddleware::effectivePermissions(
    (int) $admin['id'],
    (int) ($admin['tenant_id'] ?? 0),
    (string) $admin['role']
);

Response::success([
    'success' => true,
    'has_tenant' => $admin['tenant_id'] !== null,
    'user' => [
        'id' => (int) $admin['id'],
        'name' => $admin['name'],
        'phone' => $admin['phone'],
        'email' => $admin['email'],
        'role' => $admin['role'],
        'role_key' => $admin['role'],
        'branch_id' => $admin['branch_id'] ? (int) $admin['branch_id'] : null,
        'branch_name' => null,
        'job_title' => $employee['job_title'] ?? null,
        'tenant_id' => $admin['tenant_id'] ? (int) $admin['tenant_id'] : null,
        'permissions' => $effectivePermissions === '*'
            ? []
            : array_values($effectivePermissions),
    ],
    'tenant' => $tenant ? [
        'id' => (int) $tenant['id'],
        'name' => $tenant['name'],
        'currency' => $tenant['currency'],
        'timezone' => $tenant['timezone'],
    ] : null,
    'employee' => $employee ? [
        'id' => (int) $employee['id'],
        'job_title' => $employee['job_title'] ?? null,
        'base_salary' => (float) ($employee['base_salary'] ?? 0),
        'hire_date' => $employee['hire_date'] ?? null,
        'status' => $employee['status'] ?? null,
    ] : null,
    'pending_invitation' => $pendingInvitation,
]);
