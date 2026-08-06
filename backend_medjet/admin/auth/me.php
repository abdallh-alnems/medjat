<?php
// The signed-in super admin, plus what the account screen shows about the
// session itself: when this account last logged in, from where, and how many
// other devices are still holding a live token.
require_once __DIR__ . '/../../config/bootstrap.php';

class AdminMeApi extends AdminBaseApi {
    protected ?string $minRole = 'readonly';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $admin = AdminAuth::currentAdmin();
            $adminId = (int) $admin['admin_id'];

            $row = Database::fetchOne(
                "SELECT email, last_login_at, last_login_ip, created_at
                 FROM super_admins WHERE id = ? LIMIT 1",
                [$adminId]
            ) ?: [];

            $sessions = (int) (Database::fetchOne(
                "SELECT COUNT(*) AS c FROM super_admin_sessions
                 WHERE admin_id = ? AND expires_at > NOW()",
                [$adminId]
            )['c'] ?? 0);

            $this->success([
                'id' => $adminId,
                'username' => $admin['username'],
                'display_name' => $admin['display_name'],
                'role' => $admin['role'],
                'email' => $row['email'] ?? null,
                'last_login_at' => $row['last_login_at'] ?? null,
                'last_login_ip' => $row['last_login_ip'] ?? null,
                'created_at' => $row['created_at'] ?? null,
                'active_sessions' => $sessions,
            ]);
        }, 'admin.auth.me');
    }
}

new AdminMeApi();
