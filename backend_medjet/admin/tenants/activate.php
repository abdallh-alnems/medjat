<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class TenantActivateApi extends AdminBaseApi {
    protected ?string $minRole = 'admin';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $id = (int) $this->getField('id');
            Validator::required($id, 'id');

            TenantModel::activate($id);

            AdminAuth::logAction('tenant.activate', 'tenant', $id);
            $this->success(['message' => 'Tenant activated']);
        }, 'admin.tenants.activate');
    }
}

new TenantActivateApi();
