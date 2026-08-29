<?php
// Invite a manager into an existing company, from the support desk.
//
// The rescue path: a client whose only general manager left the business, or
// who deleted their own account, cannot invite anybody — there is nobody left
// with `add_managers`. Without this the account is permanently locked and the
// only fix is hand-written SQL on the server.
//
// Deliberately mirrors app/managers/invite.php (same table, same code, same
// email, same 72 hours). What it does NOT mirror is the equal-or-lower
// permission check, which compares against the inviter's own permissions — a
// super admin has none in that sense, and is trusted by definition.
require_once __DIR__ . '/../../../config/bootstrap.php';

class AdminInviteManagerApi extends AdminBaseApi {
    protected ?string $minRole = 'admin';

    public function __construct() {
        parent::__construct();
        Auth::requirePost();

        $this->handleRequest(function () {
            $tenantId = (int) $this->getField('tenant_id');
            if ($tenantId <= 0) {
                $this->error('معرّف الشركة مطلوب', 422);
            }

            $tenant = Database::fetchOne("SELECT id, name FROM tenants WHERE id = ? LIMIT 1", [$tenantId]);
            if (!$tenant) {
                $this->notFound('Tenant');
            }

            $email = trim((string) $this->getField('email', ''));
            if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
                $this->error('البريد الإلكتروني غير صالح', 422);
            }

            $name = trim((string) $this->getField('name', ''));
            $role = (string) $this->getField('role', 'general_manager');
            $validRoles = ['general_manager', 'hr', 'branch_manager', 'attendance', 'viewer'];
            if (!in_array($role, $validRoles, true)) {
                $this->error('الدور غير صالح', 422);
            }

            $existingAdmin = Database::fetchOne(
                "SELECT id, tenant_id FROM admins WHERE email = ? LIMIT 1",
                [$email]
            );
            if ($existingAdmin && $existingAdmin['tenant_id'] && (int) $existingAdmin['tenant_id'] !== $tenantId) {
                $this->error('هذا البريد ينتمي لشركة أخرى بالفعل', 409);
            }
            if ($existingAdmin && (int) ($existingAdmin['tenant_id'] ?? 0) === $tenantId) {
                $this->error('هذا الشخص عضو في الشركة بالفعل', 409);
            }

            $pending = Database::fetchOne(
                "SELECT id FROM manager_invitations
                 WHERE tenant_id = ? AND email = ?
                   AND cancelled_at IS NULL AND accepted_at IS NULL AND expires_at > NOW()
                 LIMIT 1",
                [$tenantId, $email]
            );
            if ($pending) {
                // Rather than refuse, hand back a fresh code — a support call is
                // usually "the code never arrived / it expired".
                $result = ManagerInvitationModel::regenerate((int) $pending['id'], $tenantId);
                if (!$result) {
                    $this->error('تعذّر إعادة إنشاء الدعوة', 500);
                    return;
                }
            } else {
                $result = ManagerInvitationModel::create($tenantId, null, [
                    'name' => $name,
                    'email' => $email,
                    'role' => $role,
                ]);
            }

            AdminAuth::logAction('admin.invite', 'tenant', $tenantId, [
                'email' => $email,
                'role' => $role,
            ]);
            AuditLogModel::log($tenantId, null, 'support.manager.invite', 'invitation', $result['id'] ?? null, [
                'email' => $email,
                'role' => $role,
            ]);

            ManagerInviteMailer::queue($email, $result['code'], $role, $tenant['name']);

            $this->success([
                'tenant_id' => $tenantId,
                'email' => $email,
                'role' => $role,
                'code' => $result['code'],
                'expires_at' => $result['expires_at'],
                'expires_in_hours' => 72,
                'join_url' => ManagerInviteMailer::joinUrl($result['code']),
            ]);
        }, 'admin.admins.invite');
    }
}

new AdminInviteManagerApi();
