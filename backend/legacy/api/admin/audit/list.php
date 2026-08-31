<?php
// Our own audit trail, made readable.
//
// It returned raw rows: an action string, a target id, an IP. Not who did it
// (the admin id was never resolved to a name), not what changed (`payload` was
// selected and then ignored), and with no way to filter — which, at 50 rows per
// page with no page control in the app, meant only the newest 50 events existed
// as far as the panel was concerned.
require_once __DIR__ . '/../../../config/bootstrap.php';

class AdminAuditListApi extends AdminBaseApi {
    protected ?string $minRole = 'readonly';

    public function __construct() {
        parent::__construct();
        $this->handleRequest(function () {
            $page = max(1, (int) ($this->getField('page') ?? 1));
            $limit = (int) ($this->getField('limit') ?? 50);
            $limit = max(10, min(200, $limit));
            $offset = ($page - 1) * $limit;

            $where = [];
            $params = [];

            $action = trim((string) ($this->getField('action') ?? ''));
            if ($action !== '') {
                // Prefix match, so 'tenant' finds tenant.create and tenant.update.
                $where[] = 'l.action LIKE ?';
                $params[] = $action . '%';
            }

            $adminId = (int) ($this->getField('admin_id') ?? 0);
            if ($adminId > 0) {
                $where[] = 'l.admin_id = ?';
                $params[] = $adminId;
            }

            $targetType = trim((string) ($this->getField('target_type') ?? ''));
            if ($targetType !== '') {
                $where[] = 'l.target_type = ?';
                $params[] = $targetType;
            }

            $from = trim((string) ($this->getField('from') ?? ''));
            if ($from !== '') {
                $where[] = 'l.created_at >= ?';
                $params[] = $from . ' 00:00:00';
            }

            $to = trim((string) ($this->getField('to') ?? ''));
            if ($to !== '') {
                $where[] = 'l.created_at <= ?';
                $params[] = $to . ' 23:59:59';
            }

            $q = trim((string) ($this->getField('q') ?? ''));
            if ($q !== '') {
                $where[] = '(l.action LIKE ? OR l.payload LIKE ? OR l.target_id LIKE ?)';
                $like = '%' . $q . '%';
                array_push($params, $like, $like, $like);
            }

            $whereSql = $where ? ('WHERE ' . implode(' AND ', $where)) : '';

            $total = (int) (Database::fetchOne(
                "SELECT COUNT(*) AS c FROM super_admin_audit_log l {$whereSql}",
                $params
            )['c'] ?? 0);

            $items = Database::fetchAll(
                "SELECT l.id, l.admin_id, l.action, l.target_type, l.target_id, l.payload, l.ip, l.created_at,
                        s.username, s.display_name
                 FROM super_admin_audit_log l
                 LEFT JOIN super_admins s ON s.id = l.admin_id
                 {$whereSql}
                 ORDER BY l.created_at DESC, l.id DESC
                 LIMIT {$limit} OFFSET {$offset}",
                $params
            );

            $this->success([
                'items' => array_map(static function (array $l): array {
                    $payload = null;
                    if (!empty($l['payload'])) {
                        $decoded = json_decode((string) $l['payload'], true);
                        // Keep the raw string when it is not valid JSON rather
                        // than dropping the only record of what happened.
                        $payload = $decoded === null ? ['raw' => $l['payload']] : $decoded;
                    }

                    return [
                        'id' => (int) $l['id'],
                        'admin_id' => $l['admin_id'] !== null ? (int) $l['admin_id'] : null,
                        'admin_name' => $l['display_name'] ?: $l['username'],
                        'action' => $l['action'],
                        'target_type' => $l['target_type'],
                        'target_id' => $l['target_id'],
                        'payload' => $payload,
                        'ip' => $l['ip'],
                        'created_at' => $l['created_at'],
                    ];
                }, $items),
                'total' => $total,
                'page' => $page,
                'limit' => $limit,
                'total_pages' => $limit > 0 ? (int) ceil($total / $limit) : 1,
            ]);
        }, 'admin.audit.list');
    }
}

new AdminAuditListApi();
