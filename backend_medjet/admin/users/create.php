<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class AdminUserCreateApi extends AdminBaseApi {
    protected ?string $minRole = 'superadmin';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $username = trim((string) $this->getField('username'));
            $password = (string) $this->getField('password');
            $displayName = $this->getField('display_name');
            $email = $this->getField('email');
            $role = (string) $this->getField('role', 'admin');

            Validator::required($username, 'username');
            Validator::required($password, 'password');

            if (mb_strlen($username) < 3) {
                $this->error('اسم المستخدم قصير جداً (3 أحرف على الأقل)', 422);
            }
            if (mb_strlen($password) < 6) {
                $this->error('كلمة المرور قصيرة جداً (6 أحرف على الأقل)', 422);
            }

            $role = Validator::enum($role, ['readonly', 'admin', 'superadmin'], 'role');

            $email = ($email !== null && $email !== '') ? trim((string) $email) : null;
            if ($email !== null && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
                $this->error('البريد الإلكتروني غير صالح', 422);
            }

            if (Database::fetchOne("SELECT id FROM super_admins WHERE username = ? LIMIT 1", [$username])) {
                $this->error('اسم المستخدم مستخدم بالفعل', 422);
            }
            if ($email !== null && Database::fetchOne("SELECT id FROM super_admins WHERE email = ? LIMIT 1", [$email])) {
                $this->error('البريد الإلكتروني مستخدم بالفعل', 422);
            }

            $hash = password_hash($password, PASSWORD_DEFAULT);

            Database::execute(
                "INSERT INTO super_admins (username, email, password_hash, display_name, role, is_active)
                 VALUES (?,?,?,?,?,1)",
                [$username, $email, $hash, ($displayName ?: null), $role]
            );

            $id = (int) Database::lastInsertId();

            AdminAuth::logAction('super_admin.create', 'super_admin', $id);

            $this->success([
                'id' => $id,
                'username' => $username,
                'display_name' => $displayName ?: $username,
                'email' => $email,
                'role' => $role,
            ]);
        }, 'admin.users.create');
    }
}

new AdminUserCreateApi();
