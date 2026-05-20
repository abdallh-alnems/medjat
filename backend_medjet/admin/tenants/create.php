<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class TenantCreateApi extends AdminBaseApi {
    protected ?string $minRole = 'superadmin';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $name = $this->getField('name');
            $ownerName = $this->getField('owner_name');
            $ownerEmail = $this->getField('owner_email');
            $plan = $this->getField('plan', 'starter');

            Validator::required($name, 'name');
            Validator::required($ownerName, 'owner_name');
            Validator::required($ownerEmail, 'owner_email');

            $tenantId = TenantModel::create([
                'name' => $name,
                'domain' => $this->getField('domain'),
                'owner_name' => $ownerName,
                'owner_email' => $ownerEmail,
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
