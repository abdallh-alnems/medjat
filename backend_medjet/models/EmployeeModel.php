<?php

final class EmployeeModel {
    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM employees WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function findByUserId(int $userId, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM employees WHERE user_id = ? AND tenant_id = ? LIMIT 1",
            [$userId, $tenantId]
        );
    }

    public static function create(int $tenantId, array $data): int {
        Database::execute(
            "INSERT INTO employees (tenant_id, branch_id, user_id, name, phone, email, job_title,
             base_salary, hire_date, national_id, status)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $data['branch_id'],
                $data['user_id'] ?? null,
                $data['name'],
                $data['phone'] ?? null,
                $data['email'] ?? null,
                $data['job_title'] ?? null,
                $data['base_salary'] ?? 0,
                $data['hire_date'] ?? date('Y-m-d'),
                $data['national_id'] ?? null,
                $data['status'] ?? 'active',
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function update(int $id, int $tenantId, array $data): void {
        $fields = [];
        $values = [];
        foreach ($data as $key => $value) {
            $fields[] = "{$key} = ?";
            $values[] = $value;
        }
        $values[] = $id;
        $values[] = $tenantId;
        Database::execute(
            "UPDATE employees SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    public static function delete(int $id, int $tenantId): bool {
        return Database::execute(
            "UPDATE employees SET status = 'terminated', deleted_at = NOW() WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }

    public static function getByTenant(int $tenantId, int $page = 1, int $limit = 20, ?int $branchId = null, ?string $search = null): array {
        $sql = "SELECT * FROM employees WHERE tenant_id = ? AND status != 'terminated'";
        $params = [$tenantId];

        if ($branchId) {
            $sql .= " AND branch_id = ?";
            $params[] = $branchId;
        }

        if ($search) {
            $sql .= " AND (name LIKE ? OR phone LIKE ? OR national_id LIKE ? OR job_title LIKE ?)";
            $searchParam = "%{$search}%";
            $params[] = $searchParam;
            $params[] = $searchParam;
            $params[] = $searchParam;
            $params[] = $searchParam;
        }

        $offset = ($page - 1) * $limit;
        $sql .= " ORDER BY name ASC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;

        $items = Database::fetchAll($sql, $params);
        return ['items' => $items, 'page' => $page];
    }

    public static function countByTenant(int $tenantId, ?int $branchId = null): int {
        $sql = "SELECT COUNT(*) as count FROM employees WHERE tenant_id = ? AND status != 'terminated'";
        $params = [$tenantId];
        if ($branchId) {
            $sql .= " AND branch_id = ?";
            $params[] = $branchId;
        }
        return (int) (Database::fetchOne($sql, $params)['count'] ?? 0);
    }
}
