<?php

final class JobOpeningModel {
    public const EMPLOYMENT_TYPES = ['full_time', 'part_time', 'contract', 'temporary'];
    public const STATUSES = ['open', 'on_hold', 'closed'];

    public static function create(int $tenantId, array $data, int $adminId): int {
        Database::execute(
            "INSERT INTO job_openings
                (tenant_id, branch_id, title, department, description, employment_type, openings_count, status, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $data['branch_id'] ?? null,
                $data['title'],
                $data['department'] ?? null,
                $data['description'] ?? null,
                $data['employment_type'] ?? 'full_time',
                (int) ($data['openings_count'] ?? 1),
                $data['status'] ?? 'open',
                $adminId,
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM job_openings WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        );
    }

    public static function listByTenant(int $tenantId, ?string $status = null): array {
        $sql = "SELECT jo.*, COUNT(c.id) AS candidates_count
                FROM job_openings jo
                LEFT JOIN candidates c ON c.job_opening_id = jo.id AND c.tenant_id = jo.tenant_id
                WHERE jo.tenant_id = ?";
        $params = [$tenantId];
        if ($status !== null && $status !== '') {
            $sql .= " AND jo.status = ?";
            $params[] = $status;
        }
        $sql .= " GROUP BY jo.id ORDER BY jo.created_at DESC";
        return Database::fetchAll($sql, $params);
    }

    public static function update(int $id, int $tenantId, array $data): void {
        $allowed = ['branch_id', 'title', 'department', 'description', 'employment_type', 'openings_count'];
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
            "UPDATE job_openings SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    public static function setStatus(int $id, int $tenantId, string $status): void {
        $closedAt = $status === 'closed' ? 'NOW()' : 'NULL';
        Database::execute(
            "UPDATE job_openings SET status = ?, closed_at = {$closedAt} WHERE id = ? AND tenant_id = ?",
            [$status, $id, $tenantId]
        );
    }
}
