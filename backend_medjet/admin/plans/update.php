<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class PlanUpdateApi extends AdminBaseApi {
    protected ?string $minRole = 'superadmin';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $id = (int) $this->getField('id');
            Validator::required($id, 'id');

            $updateData = [];
            foreach (['name', 'price', 'max_employees', 'max_branches'] as $field) {
                $val = $this->getField($field);
                if ($val !== null) {
                    $updateData[$field] = $val;
                }
            }

            if (!empty($updateData)) {
                $fields = [];
                $values = [];
                foreach ($updateData as $key => $value) {
                    $fields[] = "{$key} = ?";
                    $values[] = $value;
                }
                $values[] = $id;
                Database::execute("UPDATE plans SET " . implode(', ', $fields) . " WHERE id = ?", $values);
            }

            AdminAuth::logAction('plan.update', 'plan', $id);
            $this->success(['message' => 'Plan updated']);
        }, 'admin.plans.update');
    }
}

new PlanUpdateApi();
