<?php

final class ShiftModel {
    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM shifts WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function getByTenant(int $tenantId, ?int $branchId = null): array {
        $sql = "SELECT s.*, b.name as branch_name,
                (SELECT COUNT(*) FROM employees e WHERE e.shift_id = s.id AND e.status != 'terminated') as employee_count
                FROM shifts s
                LEFT JOIN branches b ON b.id = s.branch_id
                WHERE s.tenant_id = ? AND s.is_active = 1";
        $params = [$tenantId];
        if ($branchId !== null) {
            $sql .= " AND (s.branch_id = ? OR s.branch_id IS NULL)";
            $params[] = $branchId;
        }
        $sql .= " ORDER BY s.start_time ASC";
        return Database::fetchAll($sql, $params);
    }

    public static function create(array $data): int {
        Database::execute(
            "INSERT INTO shifts (tenant_id, branch_id, name, start_time, end_time)
             VALUES (?, ?, ?, ?, ?)",
            [
                $data['tenant_id'],
                $data['branch_id'] ?? null,
                $data['name'],
                $data['start_time'],
                $data['end_time'],
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function update(int $id, int $tenantId, array $data): void {
        $fields = [];
        $values = [];
        foreach (['name', 'branch_id', 'start_time', 'end_time', 'is_active'] as $key) {
            if (array_key_exists($key, $data)) {
                $fields[] = "{$key} = ?";
                $values[] = $data[$key];
            }
        }
        if (empty($fields)) return;
        $values[] = $id;
        $values[] = $tenantId;
        Database::execute(
            "UPDATE shifts SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    public static function delete(int $id, int $tenantId): void {
        Database::execute(
            "DELETE FROM shifts WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        );
    }

    public static function assignEmployees(int $shiftId, array $employeeIds, int $tenantId): int {
        if (empty($employeeIds)) return 0;
        $placeholders = implode(',', array_fill(0, count($employeeIds), '?'));
        $params = array_merge([$shiftId, $tenantId], $employeeIds);
        Database::execute(
            "UPDATE employees SET shift_id = ? WHERE tenant_id = ? AND id IN ({$placeholders})",
            $params
        );
        return count($employeeIds);
    }

    public static function countEmployees(int $shiftId, int $tenantId): int {
        $row = Database::fetchOne(
            "SELECT COUNT(*) AS c FROM employees
             WHERE shift_id = ? AND tenant_id = ? AND status != 'terminated'",
            [$shiftId, $tenantId]
        );
        return (int) ($row['c'] ?? 0);
    }

    public static function transferEmployees(int $fromShiftId, int $toShiftId, int $tenantId): int {
        return Database::execute(
            "UPDATE employees SET shift_id = ?
             WHERE shift_id = ? AND tenant_id = ? AND status != 'terminated'",
            [$toShiftId, $fromShiftId, $tenantId]
        );
    }

    /**
     * Copy the shift's start/end times onto each member's personal work hours,
     * so their attendance schedule stays identical after the shift is removed.
     */
    public static function applyTimesToEmployees(int $shiftId, string $startTime, string $endTime, int $tenantId): int {
        return Database::execute(
            "UPDATE employees SET work_start_time = ?, work_end_time = ?
             WHERE shift_id = ? AND tenant_id = ? AND status != 'terminated'",
            [$startTime, $endTime, $shiftId, $tenantId]
        );
    }

    public static function unassignEmployees(int $shiftId, array $employeeIds, int $tenantId): int {
        if (empty($employeeIds)) return 0;
        $placeholders = implode(',', array_fill(0, count($employeeIds), '?'));
        $params = array_merge([$tenantId, $shiftId], $employeeIds);
        Database::execute(
            "UPDATE employees SET shift_id = NULL WHERE tenant_id = ? AND shift_id = ? AND id IN ({$placeholders})",
            $params
        );
        return count($employeeIds);
    }
}
