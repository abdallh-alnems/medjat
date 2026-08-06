<?php
// Send a company administrator a password-reset email, on their behalf.
//
// Company admins authenticate through Firebase — there is no password hash in
// our database to overwrite — so "reset a client's password" means asking
// Firebase for a reset link and delivering it through our own branded email,
// exactly as app/auth/send_password_reset.php does for self-service.
//
// The difference from that endpoint: there we hide whether the account exists
// (enumeration protection for an anonymous caller). Here the caller is an
// authenticated super admin looking at a specific account, so failures are
// reported honestly — "the email never arrived" is a support call in itself.
require_once __DIR__ . '/../../config/bootstrap.php';

class AdminResetPasswordApi extends AdminBaseApi {
    protected ?string $minRole = 'admin';

    public function __construct() {
        parent::__construct();
        Auth::requirePost();

        $this->handleRequest(function () {
            $adminId = (int) $this->getField('admin_id');
            if ($adminId <= 0) {
                $this->error('معرّف المدير مطلوب', 422);
            }

            $admin = Database::fetchOne(
                "SELECT id, tenant_id, name, email, auth_provider FROM admins WHERE id = ? LIMIT 1",
                [$adminId]
            );
            if (!$admin) {
                $this->notFound('Admin');
            }

            $email = trim((string) ($admin['email'] ?? ''));
            if ($email === '') {
                $this->error('هذا الحساب بلا بريد إلكتروني — لا يمكن إرسال رابط إعادة تعيين', 422);
            }
            if ($admin['auth_provider'] !== 'email') {
                // Google/Apple accounts have no password with us to reset.
                $this->error(
                    'هذا الحساب يسجّل الدخول عبر ' . $admin['auth_provider'] . ' وليس بكلمة مرور',
                    422
                );
            }

            $lang = $this->getField('lang', 'ar');
            if (!in_array($lang, ['ar', 'en'], true)) {
                $lang = 'ar';
            }

            try {
                $link = FirebaseInit::getAuth()->getPasswordResetLink($email);

                // Route the action through our own branded page (which enforces
                // the app's password rules) instead of Firebase's default
                // handler — same swap as the self-service endpoint.
                $actionBase = getenv('APP_ACTION_URL') ?: 'https://medjatapp.com/auth-action.html';
                $q = parse_url($link, PHP_URL_QUERY);
                if ($actionBase !== '' && $q) {
                    $link = $actionBase . (strpos($actionBase, '?') !== false ? '&' : '?') . $q;
                }

                EmailService::send($email, AuthEmail::resetSubject($lang), AuthEmail::resetHtml($lang, '', $link));
            } catch (\Throwable $e) {
                error_log('Admin-initiated password reset failed: ' . $e->getMessage());
                $this->error('تعذّر إرسال رابط إعادة التعيين — راجع سجل الأخطاء', 500);
                return;
            }

            AdminAuth::logAction('admin.password_reset', 'admin', $adminId, [
                'tenant_id' => (int) $admin['tenant_id'],
                'email' => $email,
            ]);
            if ($admin['tenant_id']) {
                AuditLogModel::log(
                    (int) $admin['tenant_id'],
                    null,
                    'support.admin.password_reset',
                    'admin',
                    $adminId
                );
            }

            $this->success([
                'admin_id' => $adminId,
                'email' => $email,
                'sent' => true,
            ]);
        }, 'admin.admins.reset_password');
    }
}

new AdminResetPasswordApi();
