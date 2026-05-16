<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class PlanCreateApi extends AdminBaseApi {
    protected ?string $minRole = 'superadmin';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $name = $this->getField('name');
            $price = (float) $this->getField('price', 0);
            $maxEmployees = (int) $this->getField('max_employees', 10);
            $maxBranches = (int) $this->getField('max_branches', 1);

            Validator::required($name, 'name');

            Database::execute(
                "INSERT INTO plans (name, price, max_employees, max_branches) VALUES (?, ?, ?, ?)",
                [$name, $price, $maxEmployees, $maxBranches]
            );

            $id = (int) Database::lastInsertId();
            AdminAuth::logAction('plan.create', 'plan', $id);
            $this->success(['plan_id' => $id], 201);
        }, 'admin.plans.create');
    }
}

new PlanCreateApi();
