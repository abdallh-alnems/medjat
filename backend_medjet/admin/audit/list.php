<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class AdminAuditListApi extends AdminBaseApi {
    protected ?string $minRole = 'readonly';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $page = max(1, (int) ($this->getField('page') ?? 1));
            $limit = 50;
            $offset = ($page - 1) * $limit;

            $items = Database::fetchAll(
                "SELECT * FROM super_admin_audit_log ORDER BY created_at DESC LIMIT ? OFFSET ?",
                [$limit, $offset]
            );

            $this->success(['items' => $items, 'page' => $page]);
        }, 'admin.audit.list');
    }
}

new AdminAuditListApi();
