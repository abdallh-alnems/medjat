<?php
// Open a client's own dashboard, as them, to see what they are seeing.
//
// The last resort of a support desk: the client says "the payroll tab is
// empty", their data looks fine from here, and the difference is something only
// their session can show — their role, their permissions, their branch scope.
//
// How it works: company admins authenticate with Firebase, so we ask Firebase
// for a *custom token* bound to that admin's uid and hand it to the web app,
// which exchanges it for a real session via signInWithCustomToken. Nothing
// about our own auth is bypassed and no password is involved or revealed.
//
// Guard rails, because this is the most powerful thing the panel can do:
//   • superadmin only — not `admin`, not `readonly`;
//   • the reason is required and stored;
//   • it is written to BOTH audit logs, ours and the company's own, so the
//     client can always see that we entered their account and why;
//   • Firebase custom tokens expire after one hour and cannot be renewed here.
require_once __DIR__ . '/../../../config/bootstrap.php';

class AdminImpersonateApi extends AdminBaseApi {
    protected ?string $minRole = 'superadmin';

    public function __construct() {
        parent::__construct();
        Auth::requirePost();

        $this->handleRequest(function () {
            $adminId = (int) $this->getField('admin_id');
            $tenantId = (int) $this->getField('tenant_id');

            $reason = trim((string) $this->getField('reason', ''));
            if ($reason === '') {
                $this->error('سبب الدخول التشخيصي مطلوب (يُسجَّل للشركة)', 422);
            }

            if ($adminId > 0) {
                $admin = Database::fetchOne(
                    "SELECT id, tenant_id, name, email, role, is_active, firebase_uid
                     FROM admins WHERE id = ? LIMIT 1",
                    [$adminId]
                );
            } elseif ($tenantId > 0) {
                // No specific person named: take the company's general manager,
                // preferring one who has actually signed in before.
                $admin = Database::fetchOne(
                    "SELECT id, tenant_id, name, email, role, is_active, firebase_uid
                     FROM admins
                     WHERE tenant_id = ? AND role = 'general_manager' AND firebase_uid IS NOT NULL
                     ORDER BY is_active DESC, last_login_at IS NULL, last_login_at DESC
                     LIMIT 1",
                    [$tenantId]
                );
            } else {
                $this->error('حدّد المدير أو الشركة', 422);
                return;
            }

            if (!$admin) {
                $this->notFound('Admin');
            }
            if (empty($admin['firebase_uid'])) {
                $this->error('هذا الحساب لم يسجّل الدخول من قبل — لا يوجد حساب Firebase لانتحاله', 422);
            }
            if (!$admin['is_active']) {
                $this->error('الحساب موقوف — فعّله أولًا إن أردت الدخول به', 422);
            }

            try {
                $token = FirebaseInit::getAuth()->createCustomToken(
                    (string) $admin['firebase_uid'],
                    // Rides along inside the ID token, so anything that later
                    // wants to refuse an impersonated session can see it.
                    ['impersonated' => true, 'impersonated_by' => (int) (AdminAuth::currentAdmin()['admin_id'] ?? 0)]
                )->toString();
            } catch (\Throwable $e) {
                error_log('Impersonation token failed: ' . $e->getMessage());
                $this->error('تعذّر إنشاء رمز الدخول التشخيصي', 500);
                return;
            }

            AdminAuth::logAction('admin.impersonate', 'admin', (int) $admin['id'], [
                'tenant_id' => (int) $admin['tenant_id'],
                'email' => $admin['email'],
                'reason' => $reason,
            ]);
            if ($admin['tenant_id']) {
                AuditLogModel::log(
                    (int) $admin['tenant_id'],
                    (int) $admin['id'],
                    'support.impersonate',
                    'admin',
                    (int) $admin['id'],
                    ['reason' => $reason]
                );
            }

            $webBase = rtrim((string) (getenv('CENTRAL_WEB_URL') ?: 'https://app.permedjatapp.com'), '/');

            $this->success([
                'admin' => [
                    'id' => (int) $admin['id'],
                    'name' => $admin['name'],
                    'email' => $admin['email'],
                    'role' => $admin['role'],
                    'tenant_id' => (int) $admin['tenant_id'],
                ],
                'token' => $token,
                'url' => $webBase . '/impersonate?token=' . rawurlencode($token),
                'expires_in_minutes' => 60,
            ]);
        }, 'admin.admins.impersonate');
    }
}

new AdminImpersonateApi();
