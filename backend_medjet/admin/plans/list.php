<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class PlanListApi extends AdminBaseApi {
    protected ?string $minRole = 'readonly';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $plans = Database::fetchAll("SELECT * FROM plans ORDER BY price ASC");
            $this->success(['plans' => $plans]);
        }, 'admin.plans.list');
    }
}

new PlanListApi();
