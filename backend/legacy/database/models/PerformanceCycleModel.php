<?php

final class PerformanceCycleModel {
    public const PERIOD_TYPES = ['monthly','quarterly','semi_annual','annual','custom'];
    public const STATUSES = ['draft','active','closed'];

    public static function create(int $tenantId, array $data, int $adminId): int {
        Database::execute(
            "INSERT INTO performance_cycles (tenant_id, name, name_ar, period_type, start_date, end_date, status, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $data['name'],
                $data['name_ar'] ?? null,
                $data['period_type'] ?? 'quarterly',
                $data['start_date'],
                $data['end_date'],
                $data['status'] ?? 'draft',
                $adminId,
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM performance_cycles WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        ) ?: null;
    }

    public static function listByTenant(int $tenantId, ?string $status = null): array {
        $sql = "SELECT c.*,
                    (SELECT COUNT(*) FROM performance_goals WHERE cycle_id = c.id AND tenant_id = c.tenant_id) AS goals_count,
                    (SELECT COUNT(*) FROM performance_reviews WHERE cycle_id = c.id AND tenant_id = c.tenant_id) AS reviews_count
                FROM performance_cycles c
                WHERE c.tenant_id = ?";
        $params = [$tenantId];
        if ($status !== null) {
            $sql .= " AND c.status = ?";
            $params[] = $status;
        }
        $sql .= " ORDER BY c.created_at DESC";
        return Database::fetchAll($sql, $params);
    }

    public static function update(int $id, int $tenantId, array $data): void {
        $allowed = ['name', 'name_ar', 'period_type', 'start_date', 'end_date'];
        $fields = [];
        $values = [];
        foreach ($allowed as $key) {
            if (array_key_exists($key, $data)) {
                $fields[] = "`{$key}` = ?";
                $values[] = $data[$key];
            }
        }
        if (empty($fields)) {
            return;
        }
        $values[] = $id;
        $values[] = $tenantId;
        Database::execute(
            "UPDATE performance_cycles SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    public static function setStatus(int $id, int $tenantId, string $status): void {
        if ($status === 'closed') {
            Database::execute(
                "UPDATE performance_cycles SET status = ?, closed_at = NOW() WHERE id = ? AND tenant_id = ?",
                [$status, $id, $tenantId]
            );
        } else {
            Database::execute(
                "UPDATE performance_cycles SET status = ?, closed_at = NULL WHERE id = ? AND tenant_id = ?",
                [$status, $id, $tenantId]
            );
        }
    }
}
