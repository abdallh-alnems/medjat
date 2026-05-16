<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class SubscriptionUpdateApi extends AdminBaseApi {
    protected ?string $minRole = 'admin';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $tenantId = (int) $this->getField('tenant_id');
            $planId = (int) $this->getField('plan_id');
            $status = $this->getField('status');
            $startDate = $this->getField('start_date');
            $endDate = $this->getField('end_date');

            Validator::required($tenantId, 'tenant_id');

            if ($status) {
                SubscriptionModel::updateStatus($tenantId, $status);
            }

            if ($planId && $startDate && $endDate) {
                SubscriptionModel::create($tenantId, $planId, $startDate, $endDate);
            }

            AdminAuth::logAction('subscription.update', 'tenant', $tenantId);
            $this->success(['message' => 'Subscription updated']);
        }, 'admin.subscriptions.update');
    }
}

new SubscriptionUpdateApi();
