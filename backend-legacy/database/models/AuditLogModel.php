<?php

final class AuditLogModel {
    public static function log(int $tenantId, ?int $adminId, string $action, ?string $targetType = null, $targetId = null, ?array $payload = null): void {
        try {
            Database::execute(
                "INSERT INTO audit_log (tenant_id, admin_id, action, target_type, target_id, payload, ip) VALUES (?,?,?,?,?,?,?)",
                [
                    $tenantId,
                    $adminId,
                    $action,
                    $targetType,
                    $targetId !== null ? (string) $targetId : null,
                    $payload ? json_encode($payload, JSON_UNESCAPED_UNICODE) : null,
                    $_SERVER['REMOTE_ADDR'] ?? null,
                ]
            );
        } catch (Exception $e) {
            error_log("Audit log failed: " . $e->getMessage());
        }
    }

    public static function getByTenant(int $tenantId, int $page = 1, int $limit = 50): array {
        $offset = ($page - 1) * $limit;
        $items = Database::fetchAll(
            "SELECT * FROM audit_log WHERE tenant_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?",
            [$tenantId, $limit, $offset]
        );
        return ['items' => $items, 'page' => $page];
    }

    public static function getByAdmin(int $adminId, int $tenantId, int $page = 1, int $limit = 50): array {
        $offset = ($page - 1) * $limit;
        $items = Database::fetchAll(
            "SELECT * FROM audit_log WHERE admin_id = ? AND tenant_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?",
            [$adminId, $tenantId, $limit, $offset]
        );
        return ['items' => $items, 'page' => $page];
    }

    /**
     * Salary-change history for one employee, reconstructed from audit log
     * rows of `employee.update` whose payload mentions `base_salary`. Returns
     * the most recent first; each row has `name` (admin), `created_at`,
     * `base_salary`. Used by the financial tab's salary-history card.
     */
    public static function getBaseSalaryHistory(int $employeeId, int $tenantId, int $limit = 20): array {
        $rows = Database::fetchAll(
            "SELECT al.created_at, al.payload, a.name AS admin_name
             FROM audit_log al
             LEFT JOIN admins a ON a.id = al.admin_id
             WHERE al.tenant_id = ? AND al.action = 'employee.update'
               AND al.target_type = 'employee' AND al.target_id = ?
               AND al.payload LIKE '%base_salary%'
             ORDER BY al.created_at DESC
             LIMIT $limit",
            [$tenantId, (string) $employeeId]
        );
        $out = [];
        foreach ($rows as $r) {
            $payload = json_decode((string) ($r['payload'] ?? '{}'), true) ?: [];
            if (!array_key_exists('base_salary', $payload)) continue;
            $out[] = [
                'created_at' => $r['created_at'],
                'admin_name' => $r['admin_name'],
                'base_salary' => (float) $payload['base_salary'],
            ];
        }
        return $out;
    }

    /**
     * Management activity feed for the company management app. Only rows with a
     * non-null `admin_id` (i.e. actions taken BY the management, not employee
     * self-service requests). Joins `admins` for the actor name. Optional
     * filters: a specific admin, and a set of `action` prefixes (e.g.
     * ['loan.', 'payroll.']). Fetches `limit + 1` rows to compute `has_more`.
     */
    public static function getFeed(
        int $tenantId,
        int $page = 1,
        int $limit = 50,
        ?int $adminId = null,
        ?array $prefixes = null
    ): array {
        $offset = ($page - 1) * $limit;
        $where = ['al.tenant_id = ?', 'al.admin_id IS NOT NULL'];
        $params = [$tenantId];

        if ($adminId !== null) {
            $where[] = 'al.admin_id = ?';
            $params[] = $adminId;
        }
        if ($prefixes !== null && count($prefixes) > 0) {
            $likeParts = [];
            foreach ($prefixes as $prefix) {
                $likeParts[] = 'al.action LIKE ?';
                $params[] = $prefix . '%';
            }
            $where[] = '(' . implode(' OR ', $likeParts) . ')';
        }

        $whereSql = implode(' AND ', $where);
        $params[] = $limit + 1;
        $params[] = $offset;

        $rows = Database::fetchAll(
            "SELECT al.id, al.admin_id, al.action, al.target_type, al.target_id,
                    al.payload, al.created_at, a.name AS admin_name
             FROM audit_log al
             LEFT JOIN admins a ON a.id = al.admin_id
             WHERE $whereSql
             ORDER BY al.created_at DESC
             LIMIT ? OFFSET ?",
            $params
        );

        $hasMore = count($rows) > $limit;
        if ($hasMore) {
            array_pop($rows);
        }

        $rows = self::attachSubjects($tenantId, $rows);
        return ['items' => $rows, 'has_more' => $hasMore];
    }

    /**
     * Resolves each row's `target` (a bare type + id) into a human-readable
     * `subject` — usually the affected employee's name, e.g. the person an asset
     * was assigned to, or the entity's own name for non-employee targets. Runs
     * one batched query per distinct target type on the page (no N+1).
     */
    public static function attachSubjects(int $tenantId, array $rows): array {
        if (empty($rows)) {
            return $rows;
        }

        // target_type => SQL returning rows of {id, label} for the given ids.
        // Employee-bearing targets resolve to the employee name ("to whom");
        // the rest resolve to the entity's own name.
        $resolvers = [
            'employee'  => "SELECT id, name AS label FROM employees WHERE tenant_id = ? AND id IN (%s)",
            'asset'     => "SELECT ac.id, e.name AS label FROM asset_custody ac JOIN employees e ON e.id = ac.employee_id WHERE ac.tenant_id = ? AND ac.id IN (%s)",
            'loan'      => "SELECT l.id, e.name AS label FROM employee_loans l JOIN employees e ON e.id = l.employee_id WHERE l.tenant_id = ? AND l.id IN (%s)",
            'leave'     => "SELECT lv.id, e.name AS label FROM leaves lv JOIN employees e ON e.id = lv.employee_id WHERE lv.tenant_id = ? AND lv.id IN (%s)",
            'break'     => "SELECT br.id, e.name AS label FROM break_requests br JOIN employees e ON e.id = br.employee_id WHERE br.tenant_id = ? AND br.id IN (%s)",
            'candidate' => "SELECT id, name AS label FROM candidates WHERE tenant_id = ? AND id IN (%s)",
            'shift'     => "SELECT id, name AS label FROM shifts WHERE tenant_id = ? AND id IN (%s)",
            'branch'    => "SELECT id, name AS label FROM branches WHERE tenant_id = ? AND id IN (%s)",
        ];

        // Collect the numeric ids we need per resolvable target type.
        $idsByType = [];
        foreach ($rows as $r) {
            $type = $r['target_type'] ?? null;
            $tid = $r['target_id'] ?? null;
            if ($type === null || !isset($resolvers[$type])) continue;
            if ($tid === null || !ctype_digit((string) $tid)) continue;
            $idsByType[$type][(int) $tid] = true;
        }

        // One query per type; build [type][id] => label.
        $labels = [];
        foreach ($idsByType as $type => $idSet) {
            $ids = array_keys($idSet);
            $placeholders = implode(',', array_fill(0, count($ids), '?'));
            $sql = sprintf($resolvers[$type], $placeholders);
            try {
                $found = Database::fetchAll($sql, array_merge([$tenantId], $ids));
                foreach ($found as $f) {
                    $labels[$type][(int) $f['id']] = $f['label'];
                }
            } catch (Exception $e) {
                // A schema mismatch shouldn't break the feed; just skip subjects
                // for this type.
                error_log("Audit subject resolve failed ($type): " . $e->getMessage());
            }
        }

        foreach ($rows as &$r) {
            $type = $r['target_type'] ?? null;
            $tid = $r['target_id'] ?? null;
            $r['subject'] = ($type !== null && $tid !== null
                && ctype_digit((string) $tid)
                && isset($labels[$type][(int) $tid]))
                ? $labels[$type][(int) $tid]
                : null;
        }
        unset($r);

        return $rows;
    }

    /**
     * Distinct admins that appear as actors in this tenant's audit log, for the
     * "filter by who" dropdown. Most recently active first.
     */
    public static function getActors(int $tenantId): array {
        return Database::fetchAll(
            "SELECT al.admin_id AS id, a.name AS name, MAX(al.created_at) AS last_seen
             FROM audit_log al
             LEFT JOIN admins a ON a.id = al.admin_id
             WHERE al.tenant_id = ? AND al.admin_id IS NOT NULL
             GROUP BY al.admin_id, a.name
             ORDER BY last_seen DESC",
            [$tenantId]
        );
    }

    /**
     * Audit entries for actions whose `action` starts with `$prefix` (e.g.
     * `payroll.`). Joins with admins so the UI can render "who did what".
     */
    public static function getByActionPrefix(int $tenantId, string $prefix, int $page = 1, int $limit = 50): array {
        $offset = ($page - 1) * $limit;
        $like = $prefix . '%';
        $items = Database::fetchAll(
            "SELECT al.id, al.admin_id, al.action, al.target_type, al.target_id,
                    al.payload, al.created_at, a.name AS admin_name
             FROM audit_log al
             LEFT JOIN admins a ON a.id = al.admin_id
             WHERE al.tenant_id = ? AND al.action LIKE ?
             ORDER BY al.created_at DESC
             LIMIT ? OFFSET ?",
            [$tenantId, $like, $limit, $offset]
        );
        return ['items' => $items, 'page' => $page];
    }
}
