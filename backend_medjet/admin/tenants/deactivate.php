<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class TenantDeactivateApi extends AdminBaseApi {
    protected ?string $minRole = 'admin';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $id = (int) $this->getField('id');
            Validator::required($id, 'id');

            TenantModel::deactivate($id);
            SubscriptionModel::updateStatus($id, 'suspended');

            AdminAuth::logAction('tenant.deactivate', 'tenant', $id);
            $this->success(['message' => 'Tenant deactivated']);
        }, 'admin.tenants.deactivate');
    }
}

new TenantDeactivateApi();
