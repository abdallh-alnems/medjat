<?php
// Suspend or restore a company administrator from the support desk.
//
// Same semantics as the company's own app/managers/set_admin_active.php: this
// is a suspension, not a removal — the account keeps its company and its role,
// it simply stops authenticating (Auth::authenticateUser rejects is_active = 0
// with 'account_deactivated').
require_once __DIR__ . '/../../config/bootstrap.php';

class AdminSetActiveApi extends AdminBaseApi {
    protected ?string $minRole = 'admin';

    public function __construct() {
        parent::__construct();
        Auth::requirePost();

        $this->handleRequest(function () {
            $adminId = (int) $this->getField('admin_id');
            if ($adminId <= 0) {
                $this->error('معرّف المدير مطلوب', 422);
            }

            $isActive = $this->getField('is_active');
            if ($isActive === null) {
                $this->error('is_active مطلوب', 422);
            }
            $isActive = (int) ((bool) filter_var($isActive, FILTER_VALIDATE_BOOLEAN)
                || $isActive === 1 || $isActive === '1');

            $admin = Database::fetchOne(
                "SELECT id, tenant_id, name, email, is_active FROM admins WHERE id = ? LIMIT 1",
                [$adminId]
            );
            if (!$admin) {
                $this->notFound('Admin');
            }

            Database::execute("UPDATE admins SET is_active = ? WHERE id = ?", [$isActive, $adminId]);

            AdminAuth::logAction(
                $isActive ? 'admin.activate' : 'admin.deactivate',
                'admin',
                $adminId,
                ['tenant_id' => (int) $admin['tenant_id'], 'email' => $admin['email']]
            );
            if ($admin['tenant_id']) {
                // Also visible to the company itself, so a suspension we applied
                // is never a mystery in their own audit trail.
                AuditLogModel::log(
                    (int) $admin['tenant_id'],
                    null,
                    $isActive ? 'support.admin.activate' : 'support.admin.deactivate',
                    'admin',
                    $adminId
                );
            }

            $this->success([
                'admin_id' => $adminId,
                'is_active' => $isActive,
            ]);
        }, 'admin.admins.set_active');
    }
}

new AdminSetActiveApi();
