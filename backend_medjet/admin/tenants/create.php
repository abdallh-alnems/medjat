<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class TenantCreateApi extends AdminBaseApi {
    protected ?string $minRole = 'superadmin';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $name = $this->getField('name');

            Validator::required($name, 'name');

            $tenantId = TenantModel::create([
                'name' => $name,
            ]);

            AdminAuth::logAction('tenant.create', 'tenant', $tenantId);
            $this->success(['tenant_id' => $tenantId], 201);
        }, 'admin.tenants.create');
    }
}

new TenantCreateApi();
