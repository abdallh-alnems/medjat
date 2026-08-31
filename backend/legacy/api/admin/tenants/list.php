<?php
// The client list, searchable and paginated.
//
// It used to return `SELECT *` from tenants, 20 at a time, with no search and
// no way to reach page 2 — past twenty companies the rest were unreachable from
// the panel. Each row now also carries the numbers you want before deciding to
// open a company at all: who to call, how big they are, and whether anyone has
// used the system lately.
require_once __DIR__ . '/../../../config/bootstrap.php';

class TenantListApi extends AdminBaseApi {
    protected ?string $minRole = 'readonly';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $page = max(1, (int) ($this->getField('page') ?? 1));
            $limit = (int) ($this->getField('limit') ?? 20);
            $limit = max(5, min(100, $limit));
            $offset = ($page - 1) * $limit;

            $where = [];
            $params = [];

            $q = trim((string) ($this->getField('q') ?? ''));
            if ($q !== '') {
                $where[] = '(t.name LIKE ? OR t.contact_name LIKE ? OR t.contact_phone LIKE ? OR t.contact_email LIKE ?)';
                $like = '%' . $q . '%';
                array_push($params, $like, $like, $like, $like);
            }

            $status = (string) ($this->getField('status') ?? '');
            if ($status === 'active') {
                $where[] = 't.is_active = 1';
            } elseif ($status === 'inactive') {
                $where[] = 't.is_active = 0';
            }

            $whereSql = $where ? ('WHERE ' . implode(' AND ', $where)) : '';

            $total = (int) (Database::fetchOne(
                "SELECT COUNT(*) AS c FROM tenants t {$whereSql}",
                $params
            )['c'] ?? 0);

            // Correlated subqueries rather than joins + GROUP BY: the row count
            // here is in the tens, and this keeps each number independent (a
            // company with no branches still reports its employees correctly).
            // LIMIT/OFFSET are interpolated rather than bound so they cannot be
            // mixed up with the variable-length WHERE parameters; both are
            // already clamped ints, so there is nothing to inject.
            $items = Database::fetchAll(
                "SELECT t.id, t.name, t.is_active, t.timezone, t.currency, t.created_at,
                        t.contact_name, t.contact_email, t.contact_phone,
                        (SELECT COUNT(*) FROM employees e WHERE e.tenant_id = t.id AND e.status = 'active') AS employee_count,
                        (SELECT COUNT(*) FROM branches b WHERE b.tenant_id = t.id) AS branch_count,
                        (SELECT COUNT(*) FROM admins a WHERE a.tenant_id = t.id AND a.role NOT IN ('employee','pending')) AS admin_count,
                        (SELECT MAX(a.last_login_at) FROM admins a WHERE a.tenant_id = t.id) AS last_admin_login_at,
                        (SELECT MAX(at.date) FROM attendance at WHERE at.tenant_id = t.id AND at.check_in_time IS NOT NULL) AS last_attendance_date
                 FROM tenants t
                 {$whereSql}
                 ORDER BY t.created_at DESC
                 LIMIT {$limit} OFFSET {$offset}",
                $params
            );

            $this->success([
                'items' => array_map(static function (array $t): array {
                    return [
                        'id' => (int) $t['id'],
                        'name' => $t['name'],
                        'is_active' => (int) $t['is_active'],
                        'timezone' => $t['timezone'],
                        'currency' => $t['currency'],
                        'created_at' => $t['created_at'],
                        'contact_name' => $t['contact_name'],
                        'contact_email' => $t['contact_email'],
                        'contact_phone' => $t['contact_phone'],
                        'employee_count' => (int) $t['employee_count'],
                        'branch_count' => (int) $t['branch_count'],
                        'admin_count' => (int) $t['admin_count'],
                        'last_admin_login_at' => $t['last_admin_login_at'],
                        'last_attendance_date' => $t['last_attendance_date'],
                    ];
                }, $items),
                'total' => $total,
                'page' => $page,
                'limit' => $limit,
                'total_pages' => $limit > 0 ? (int) ceil($total / $limit) : 1,
            ]);
        }, 'admin.tenants.list');
    }
}

new TenantListApi();
