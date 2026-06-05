<?php

final class PerformanceGoalModel {
    public const STATUSES = ['not_started','in_progress','completed','cancelled'];

    public static function create(int $tenantId, array $data, int $adminId): int {
        Database::execute(
            "INSERT INTO performance_goals (tenant_id, employee_id, cycle_id, title, description, metric, target_value, current_value, weight, progress, status, due_date, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $data['employee_id'],
                $data['cycle_id'] ?? null,
                $data['title'],
                $data['description'] ?? null,
                $data['metric'] ?? null,
                $data['target_value'] ?? null,
                $data['current_value'] ?? 0.00,
                $data['weight'] ?? 0,
                $data['progress'] ?? 0,
                $data['status'] ?? 'not_started',
                $data['due_date'] ?? null,
                $adminId,
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM performance_goals WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        ) ?: null;
    }

    public static function listByEmployee(int $tenantId, int $employeeId, ?int $cycleId = null): array {
        $sql = "SELECT * FROM performance_goals WHERE tenant_id = ? AND employee_id = ?";
        $params = [$tenantId, $employeeId];
        if ($cycleId !== null) {
            $sql .= " AND cycle_id = ?";
            $params[] = $cycleId;
        }
        $sql .= " ORDER BY created_at DESC";
        return Database::fetchAll($sql, $params);
    }

    public static function update(int $id, int $tenantId, array $data): void {
        $allowed = ['title', 'description', 'metric', 'target_value', 'current_value', 'weight', 'due_date', 'cycle_id', 'status'];
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
            "UPDATE performance_goals SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    public static function setProgress(int $id, int $tenantId, int $progress, ?string $status = null): void {
        $progress = max(0, min(100, $progress));

        if ($status === null) {
            if ($progress === 100) {
                $status = 'completed';
            } elseif ($progress > 0) {
                $status = 'in_progress';
            } else {
                $status = 'not_started';
            }
        }

        Database::execute(
            "UPDATE performance_goals SET progress = ?, status = ? WHERE id = ? AND tenant_id = ?",
            [$progress, $status, $id, $tenantId]
        );
    }

    public static function delete(int $id, int $tenantId): bool {
        return Database::execute(
            "DELETE FROM performance_goals WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }

    public static function summary(int $tenantId, int $employeeId, ?int $cycleId = null): array {
        $sql = "SELECT
                    COUNT(*) AS total,
                    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed,
                    AVG(progress) AS avg_progress
                FROM performance_goals
                WHERE tenant_id = ? AND employee_id = ?";
        $params = [$tenantId, $employeeId];
        if ($cycleId !== null) {
            $sql .= " AND cycle_id = ?";
            $params[] = $cycleId;
        }
        $row = Database::fetchOne($sql, $params);
        return [
            'total' => (int) ($row['total'] ?? 0),
            'completed' => (int) ($row['completed'] ?? 0),
            'avg_progress' => round((float) ($row['avg_progress'] ?? 0), 1),
        ];
    }
}
