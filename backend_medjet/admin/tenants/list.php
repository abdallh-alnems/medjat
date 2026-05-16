<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class TenantListApi extends AdminBaseApi {
    protected ?string $minRole = 'readonly';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $page = max(1, (int) ($this->getField('page') ?? 1));
            $result = TenantModel::getAll($page);
            $this->success($result);
        }, 'admin.tenants.list');
    }
}

new TenantListApi();
