<?php
// The client contact book: every company administrator on the platform.
//
// Two things this list is NOT. It is not the super-admin team (those live in
// `super_admins`, which is what admin/users/create.php writes to — the panel
// used to list one table and create rows in the other, so a super admin you
// created never appeared anywhere). And it is not a directory of employees.
//
// It is the answer to "who do I call at this company", which is why it carries
// the company name, the phone, the email and — the number that decides whether
// a support call is even worth making — when they last signed in.
require_once __DIR__ . '/../../../config/bootstrap.php';

class AdminUserListApi extends AdminBaseApi {
    protected ?string $minRole = 'readonly';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $page = max(1, (int) ($this->getField('page') ?? 1));
            $limit = (int) ($this->getField('limit') ?? 20);
            $limit = max(5, min(100, $limit));
            $offset = ($page - 1) * $limit;

            // 'employee' rows are staff accounts that happen to share the table;
            // they are not contacts. 'pending' is kept — someone mid-signup is
            // exactly who calls support.
            $where = ["a.role <> 'employee'"];
            $params = [];

            $tenantId = (int) ($this->getField('tenant_id') ?? 0);
            if ($tenantId > 0) {
                $where[] = 'a.tenant_id = ?';
                $params[] = $tenantId;
            }

            $q = trim((string) ($this->getField('q') ?? ''));
            if ($q !== '') {
                $where[] = '(a.name LIKE ? OR a.email LIKE ? OR a.phone LIKE ? OR t.name LIKE ?)';
                $like = '%' . $q . '%';
                array_push($params, $like, $like, $like, $like);
            }

            $role = trim((string) ($this->getField('role') ?? ''));
            if ($role !== '') {
                $where[] = 'a.role = ?';
                $params[] = $role;
            }

            $status = (string) ($this->getField('status') ?? '');
            if ($status === 'active') {
                $where[] = 'a.is_active = 1';
            } elseif ($status === 'inactive') {
                $where[] = 'a.is_active = 0';
            }

            $whereSql = 'WHERE ' . implode(' AND ', $where);

            $total = (int) (Database::fetchOne(
                "SELECT COUNT(*) AS c FROM admins a LEFT JOIN tenants t ON t.id = a.tenant_id {$whereSql}",
                $params
            )['c'] ?? 0);

            $items = Database::fetchAll(
                "SELECT a.id, a.tenant_id, a.branch_id, a.name, a.phone, a.email, a.role,
                        a.auth_provider, a.is_active, a.last_login_at, a.created_at,
                        t.name AS tenant_name, t.is_active AS tenant_is_active
                 FROM admins a
                 LEFT JOIN tenants t ON t.id = a.tenant_id
                 {$whereSql}
                 ORDER BY a.last_login_at IS NULL, a.last_login_at DESC, a.id DESC
                 LIMIT {$limit} OFFSET {$offset}",
                $params
            );

            $this->success([
                'items' => array_map(static function (array $a): array {
                    return [
                        'id' => (int) $a['id'],
                        'tenant_id' => $a['tenant_id'] !== null ? (int) $a['tenant_id'] : null,
                        'tenant_name' => $a['tenant_name'],
                        'tenant_is_active' => $a['tenant_is_active'] !== null ? (int) $a['tenant_is_active'] : null,
                        'branch_id' => $a['branch_id'] !== null ? (int) $a['branch_id'] : null,
                        'name' => $a['name'],
                        'phone' => $a['phone'],
                        'email' => $a['email'],
                        'role' => $a['role'],
                        'auth_provider' => $a['auth_provider'],
                        'is_active' => (int) $a['is_active'],
                        'last_login_at' => $a['last_login_at'],
                        'created_at' => $a['created_at'],
                    ];
                }, $items),
                'total' => $total,
                'page' => $page,
                'limit' => $limit,
                'total_pages' => $limit > 0 ? (int) ceil($total / $limit) : 1,
            ]);
        }, 'admin.users.list');
    }
}

new AdminUserListApi();
