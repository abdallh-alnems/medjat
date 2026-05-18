<?php
require_once __DIR__ . '/../../config/bootstrap.php';

class AdminUserListApi extends AdminBaseApi {
    protected ?string $minRole = 'readonly';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $tenantId = ($this->getField('tenant_id')) ? (int) $this->getField('tenant_id') : null;
            $page = max(1, (int) ($this->getField('page') ?? 1));
            $limit = 20;

            if ($tenantId) {
                $result = AdminModel::getByTenant($tenantId, $page, $limit);
            } else {
                $offset = ($page - 1) * $limit;
                $items = Database::fetchAll(
                    "SELECT id, tenant_id, branch_id, name, phone, email, role, is_active, created_at FROM admins ORDER BY created_at DESC LIMIT ? OFFSET ?",
                    [$limit, $offset]
                );
                $total = Database::fetchOne("SELECT COUNT(*) as count FROM admins")['count'];
                $result = ['items' => $items, 'total' => (int) $total, 'page' => $page];
            }

            $this->success($result);
        }, 'admin.users.list');
    }
}

new AdminUserListApi();
