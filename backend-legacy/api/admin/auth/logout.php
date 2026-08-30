<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

class AdminLogoutApi extends AdminBaseApi {
    protected ?string $minRole = 'readonly';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            AdminAuth::logout();
            $this->success(['message' => 'Logged out']);
        }, 'admin.auth.logout');
    }
}

new AdminLogoutApi();
