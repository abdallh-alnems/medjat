<?php
// Change your own super-admin password.
//
// The one piece of account management a single-operator panel genuinely needs:
// without it, a forgotten password means hand-written SQL on the production
// server, which the project rules forbid outright.
//
// Every other session is dropped on success — a password change that leaves the
// old sessions alive protects nothing.
require_once __DIR__ . '/../../../config/bootstrap.php';

class AdminChangePasswordApi extends AdminBaseApi {
    protected ?string $minRole = 'readonly';

    public function __construct() {
        parent::__construct();
        Auth::requirePost();

        $this->handleRequest(function () {
            $admin = AdminAuth::currentAdmin();
            $adminId = (int) ($admin['admin_id'] ?? 0);
            if ($adminId <= 0) {
                $this->error('غير مصرح', 401);
            }

            $current = (string) $this->getField('current_password', '');
            $new = (string) $this->getField('new_password', '');

            if ($current === '' || $new === '') {
                $this->error('كلمة المرور الحالية والجديدة مطلوبتان', 422);
            }
            if (mb_strlen($new) < 8) {
                $this->error('كلمة المرور الجديدة قصيرة جدًا (8 أحرف على الأقل)', 422);
            }
            if ($new === $current) {
                $this->error('كلمة المرور الجديدة مطابقة للحالية', 422);
            }

            $row = Database::fetchOne(
                "SELECT password_hash FROM super_admins WHERE id = ? LIMIT 1",
                [$adminId]
            );
            if (!$row || !password_verify($current, $row['password_hash'])) {
                AdminAuth::logAction('auth.change_password_failed', 'super_admin', $adminId);
                $this->error('كلمة المرور الحالية غير صحيحة', 401);
            }

            Database::execute(
                "UPDATE super_admins SET password_hash = ? WHERE id = ?",
                [password_hash($new, PASSWORD_DEFAULT), $adminId]
            );

            // Keep the session that made the change; sign every other one out.
            $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
            $currentHash = preg_match('/Bearer\s+(.+)/i', $header, $m)
                ? hash('sha256', trim($m[1]))
                : '';

            Database::execute(
                "DELETE FROM super_admin_sessions WHERE admin_id = ? AND token_hash <> ?",
                [$adminId, $currentHash]
            );

            AdminAuth::logAction('auth.change_password', 'super_admin', $adminId);

            $this->success(['changed' => true]);
        }, 'admin.auth.change_password');
    }
}

new AdminChangePasswordApi();
