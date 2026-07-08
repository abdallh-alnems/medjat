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
// returned for in-person / QR sharing.
$tenantRow = Database::fetchOne("SELECT name FROM tenants WHERE id = ? LIMIT 1", [$tenantId]);
$companyName = $tenantRow['name'] ?? '';
$inviteCode = $result['code'];
$inviteRole = $role;
$inviteEmail = $email;
$webBase = rtrim((string) (getenv('CENTRAL_WEB_URL') ?: ''), '/');

// Public URL of the bridge landing page that opens the app (via its custom
// scheme) and falls back to web/store. Derived from this request so it works on
// whatever host the backend is served from.
$scriptName = $_SERVER['SCRIPT_NAME'] ?? '';
$appPos = strpos($scriptName, '/app/');
$backendRoot = $appPos !== false ? substr($scriptName, 0, $appPos) : '';
$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host = $_SERVER['HTTP_HOST'] ?? 'api.medjatapp.com';
$joinTeamUrl = $scheme . '://' . $host . $backendRoot
    . '/join_team.php?code=' . rawurlencode($inviteCode);

Background::defer(static function () use (
    $inviteEmail, $inviteCode, $inviteRole, $companyName, $webBase, $joinTeamUrl
) {
    try {
        $roleLabels = [
            'general_manager' => 'مدير عام',
            'hr' => 'موارد بشرية',
            'branch_manager' => 'مدير فرع',
            'attendance' => 'مسؤول حضور',
            'viewer' => 'مشاهد',
        ];
        $roleLabel = $roleLabels[$inviteRole] ?? $inviteRole;
        $safeCompany = htmlspecialchars($companyName, ENT_QUOTES, 'UTF-8');
        $safeRole = htmlspecialchars($roleLabel, ENT_QUOTES, 'UTF-8');
        $safeCode = htmlspecialchars($inviteCode, ENT_QUOTES, 'UTF-8');

        $intro = $companyName !== ''
            ? "تمت دعوتك للانضمام إلى فريق «{$safeCompany}» على Medjat بدور <strong>{$safeRole}</strong>."
            : "تمت دعوتك للانضمام إلى فريق على Medjat بدور <strong>{$safeRole}</strong>.";

        $safeJoin = htmlspecialchars($joinTeamUrl, ENT_QUOTES, 'UTF-8');
        $linkBlock =
            '<p style="text-align:center;margin:24px 0;">'
            . '<a href="' . $safeJoin . '" style="display:inline-block;background:#2E7D6B;color:#fff;'
            . 'text-decoration:none;padding:14px 32px;border-radius:8px;font-weight:600;font-size:16px;">'
            . 'فتح التطبيق والانضمام</a>'
            . '</p>';
        if ($webBase !== '') {
            $webUrl = htmlspecialchars(
                $webBase . '/onboarding?code=' . rawurlencode($inviteCode),
                ENT_QUOTES,
                'UTF-8'
            );
            $linkBlock .=
                '<p style="text-align:center;margin:-8px 0 8px;">'
                . '<a href="' . $webUrl . '" style="color:#2E7D6B;font-size:14px;">أو الفتح من المتصفح</a>'
                . '</p>';
        }

        $html = '<!DOCTYPE html><html dir="rtl" lang="ar">'
            . '<head><meta charset="UTF-8"></head>'
            . '<body style="font-family:\'IBM Plex Sans Arabic\',Tahoma,Arial,sans-serif;direction:rtl;text-align:right;padding:24px;background:#f9f9f9;">'
            . '<div style="max-width:480px;margin:0 auto;background:#fff;border-radius:12px;padding:32px;box-shadow:0 2px 8px rgba(0,0,0,0.06);">'
            . '<h2 style="color:#1a1a1a;margin:0 0 16px;">دعوة للانضمام إلى الفريق</h2>'
            . '<p style="color:#444;font-size:15px;line-height:1.7;">' . $intro . '</p>'
            . '<p style="color:#444;font-size:15px;line-height:1.7;">استخدم رمز الدعوة التالي:</p>'
            . '<div style="text-align:center;margin:16px 0;">'
            . '<span style="display:inline-block;border:2px solid #2E7D6B;border-radius:8px;padding:14px 28px;'
            . 'font-size:28px;font-weight:700;letter-spacing:6px;color:#2E7D6B;">' . $safeCode . '</span>'
            . '</div>'
            . $linkBlock
            . '<p style="color:#444;font-size:14px;line-height:1.8;">'
            . 'افتح تطبيق Medjat للإدارة (أو الموقع)، ثم اختر «الانضمام إلى شركة» وأدخل هذا الرمز. '
            . 'إن لم يكن لديك حساب بعد، أنشئ حسابًا بنفس هذا البريد الإلكتروني أولًا.'
            . '</p>'
            . '<hr style="border:none;border-top:1px solid #eee;margin:20px 0;">'
            . '<p style="color:#888;font-size:13px;line-height:1.6;">هذا الرمز صالح لمدة 72 ساعة ويُستخدم مرة واحدة. إن لم تكن تتوقع هذه الدعوة، تجاهل هذه الرسالة.</p>'
            . '</div></body></html>';

        EmailService::send($inviteEmail, 'دعوة للانضمام إلى فريق على Medjat', $html);
    } catch (\Throwable $e) {
        error_log('Invite email failed: ' . $e->getMessage());
    }
});

Response::success([
    'invitation_id' => $result['id'],
    'invitation_code' => $result['code'],
    'expires_at' => $result['expires_at'],
    'expires_in_hours' => 72,
], 201);
