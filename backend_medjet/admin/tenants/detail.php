<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class TenantDetailApi extends AdminBaseApi {
    protected ?string $minRole = 'readonly';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $id = (int) $this->getField('id');
            Validator::required($id, 'id');

            $tenant = TenantModel::findById($id);
            if (!$tenant) {
                $this->notFound('Tenant');
            }

            $employeeCount = TenantModel::getEmployeeCount($id);
            $branchCount = TenantModel::getBranchCount($id);
            $subscription = SubscriptionModel::findByTenant($id);

            $this->success([
                'tenant' => $tenant,
                'stats' => [
                    'employees' => $employeeCount,
                    'branches' => $branchCount,
                ],
                'subscription' => $subscription,
            ]);
        }, 'admin.tenants.detail');
    }
}

new TenantDetailApi();
