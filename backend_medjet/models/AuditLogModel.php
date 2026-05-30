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
