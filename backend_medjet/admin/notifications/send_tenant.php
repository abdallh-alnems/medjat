<?php
// Announcement to one company. Same audience choice as the platform-wide send:
// `sendToTenant` joins `admins`, so on its own it never reaches an employee.
require_once __DIR__ . '/../../config/bootstrap.php';

class NotificationSendTenantApi extends AdminBaseApi {
    protected ?string $minRole = 'admin';

    public function __construct() {
        parent::__construct();
        Auth::requirePost();

        $this->handleRequest(function () {
            $tenantId = (int) $this->getField('tenant_id');
            $title = $this->getField('title');
            $body = $this->getField('body');

            Validator::required($tenantId, 'tenant_id');
            Validator::required($title, 'title');
            Validator::required($body, 'body');

            $audience = (string) $this->getField('audience', 'admins');
            if (!in_array($audience, ['admins', 'employees', 'all'], true)) {
                $this->error('الجمهور غير صالح', 422);
            }

            $tenant = Database::fetchOne("SELECT id, name FROM tenants WHERE id = ? LIMIT 1", [$tenantId]);
            if (!$tenant) {
                $this->notFound('Tenant');
            }

            $sentAdmins = ($audience === 'admins' || $audience === 'all')
                ? NotificationService::sendToTenant($tenantId, $title, $body)
                : 0;

            $sentEmployees = ($audience === 'employees' || $audience === 'all')
                ? NotificationService::sendToTenantEmployees($tenantId, $title, $body)
                : 0;

            AdminAuth::logAction('notification.send_tenant', 'tenant', $tenantId, [
                'title' => $title,
                'audience' => $audience,
                'sent_admins' => $sentAdmins,
                'sent_employees' => $sentEmployees,
            ]);

            $this->success([
                'tenant_id' => $tenantId,
                'tenant_name' => $tenant['name'],
                'audience' => $audience,
                'sent_admins' => $sentAdmins,
                'sent_employees' => $sentEmployees,
                'sent' => $sentAdmins + $sentEmployees,
            ]);
        }, 'admin.notifications.send_tenant');
    }
}

new NotificationSendTenantApi();
