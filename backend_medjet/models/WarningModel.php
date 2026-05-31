<?php

final class WarningModel {
    public static function add(int $employeeId, int $tenantId, string $type, string $reason, int $issuedBy): int {
        Database::execute(
            "INSERT INTO warnings (tenant_id, employee_id, type, reason, issued_by) VALUES (?, ?, ?, ?, ?)",
            [$tenantId, $employeeId, $type, $reason, $issuedBy]
        );
        return (int) Database::lastInsertId();
    }

    public static function getByEmployee(int $employeeId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT w.*, a.name as issued_by_name FROM warnings w
             LEFT JOIN admins a ON a.id = w.issued_by
             WHERE w.employee_id = ? AND w.tenant_id = ?
             ORDER BY w.created_at DESC",
            [$employeeId, $tenantId]
        );
    }

    public static function getByTenant(int $tenantId, int $page = 1, int $limit = 20): array {
        $offset = ($page - 1) * $limit;
        $items = Database::fetchAll(
            "SELECT w.*, e.name as employee_name FROM warnings w
             JOIN employees e ON e.id = w.employee_id
             WHERE w.tenant_id = ?
             ORDER BY w.created_at DESC LIMIT ? OFFSET ?",
            [$tenantId, $limit, $offset]
        );
        return ['items' => $items, 'page' => $page];
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM warnings WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        );
    }

    public static function delete(int $id, int $tenantId): bool {
        return Database::execute(
            "DELETE FROM warnings WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }
}
