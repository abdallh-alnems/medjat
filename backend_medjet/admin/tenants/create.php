<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class TenantCreateApi extends AdminBaseApi {
    protected ?string $minRole = 'superadmin';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $name = $this->getField('name');
            $plan = $this->getField('plan', 'starter');

            Validator::required($name, 'name');

            $tenantId = TenantModel::create([
                'name' => $name,
                'domain' => $this->getField('domain'),
                'plan' => $plan,
            ]);

            $planRow = Database::fetchOne("SELECT id FROM plans WHERE name = ? LIMIT 1", [$plan]);
            if ($planRow) {
                SubscriptionModel::create($tenantId, $planRow['id'], date('Y-m-d'), date('Y-m-d', strtotime('+1 month')));
            }

            AdminAuth::logAction('tenant.create', 'tenant', $tenantId);
            $this->success(['tenant_id' => $tenantId], 201);
        }, 'admin.tenants.create');
    }
}

new TenantCreateApi();
