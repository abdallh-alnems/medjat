<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class NotificationSendTenantApi extends AdminBaseApi {
    protected ?string $minRole = 'admin';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $tenantId = (int) $this->getField('tenant_id');
            $title = $this->getField('title');
            $body = $this->getField('body');

            Validator::required($tenantId, 'tenant_id');
            Validator::required($title, 'title');
            Validator::required($body, 'body');

            $sent = NotificationService::sendToTenant($tenantId, $title, $body);

            AdminAuth::logAction('notification.send_tenant', 'tenant', $tenantId, ['title' => $title]);
            $this->success(['sent' => $sent]);
        }, 'admin.notifications.send_tenant');
    }
}

new NotificationSendTenantApi();
