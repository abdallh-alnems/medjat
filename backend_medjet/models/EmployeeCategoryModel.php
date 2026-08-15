<?php

final class EmployeeCategoryModel {
    public static function listByTenant(int $tenantId, bool $activeOnly = false): array {
        // Count only non-terminated employees so the tile figure matches the
        // employee list (which never shows terminated staff).
        $sql = "SELECT ec.*,
                (SELECT COUNT(*) FROM employee_category_assignments eca
                 JOIN employees e ON e.id = eca.employee_id AND e.tenant_id = eca.tenant_id
                 WHERE eca.category_id = ec.id AND eca.tenant_id = ec.tenant_id
                   AND e.status != 'terminated') AS employee_count
                FROM employee_categories ec
                WHERE ec.tenant_id = ?";
        $params = [$tenantId];
        if ($activeOnly) {
            $sql .= " AND ec.is_active = 1";
        }
        $sql .= " ORDER BY ec.name ASC";
        return Database::fetchAll($sql, $params);
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM employee_categories WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function findByName(string $name, int $tenantId, ?int $excludeId = null): ?array {
        $sql = "SELECT * FROM employee_categories WHERE name = ? AND tenant_id = ?";
        $params = [$name, $tenantId];
        if ($excludeId) {
            $sql .= " AND id != ?";
            $params[] = $excludeId;
        }
        $sql .= " LIMIT 1";
        return Database::fetchOne($sql, $params);
    }

    public static function create(int $tenantId, string $name, ?string $description = null, ?string $color = null): int {
        Database::execute(
            "INSERT INTO employee_categories (tenant_id, name, description, color) VALUES (?, ?, ?, ?)",
            [$tenantId, $name, $description, $color]
        );
        return (int) Database::lastInsertId();
    }

    public static function update(int $id, int $tenantId, array $fields): bool {
        $allowed = ['name', 'description', 'color', 'is_active'];
        $sets = [];
        $vals = [];
        foreach ($allowed as $col) {
            if (array_key_exists($col, $fields)) {
                $sets[] = "{$col} = ?";
                $vals[] = $fields[$col];
            }
        }
        if (empty($sets)) return false;
        $vals[] = $id;
        $vals[] = $tenantId;
        return Database::execute(
            "UPDATE employee_categories SET " . implode(', ', $sets) . " WHERE id = ? AND tenant_id = ?",
            $vals
        ) > 0;
    }

    /**
     * The browser-channel exception for a category: 1 allow, 0 refuse, null
     * inherit the company switch.
     *
     * Deliberately not folded into the `$allowed` whitelist in update() above.
     * That list is what an ordinary category edit may touch (`manage_employees`);
     * this column is an attendance-security decision gated on
     * `manage_company_settings`, and mixing them would let the weaker permission
     * carry the stronger change in a general update body.
     */
    public static function setWebAccess(int $id, int $tenantId, ?int $value): bool {
        return Database::execute(
            "UPDATE employee_categories SET web_attendance_allowed = ? WHERE id = ? AND tenant_id = ?",
            [$value, $id, $tenantId]
        ) > 0;
    }

    public static function isUsedByDocuments(int $categoryId, int $tenantId): bool {
        $row = Database::fetchOne(
            "SELECT COUNT(*) AS cnt FROM required_document_categories WHERE category_id = ? AND tenant_id = ?",
            [$categoryId, $tenantId]
        );
        return ($row['cnt'] ?? 0) > 0;
    }

    public static function delete(int $id, int $tenantId): bool {
        return Database::execute(
            "DELETE FROM employee_categories WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }

    public static function assignToEmployee(int $employeeId, int $tenantId, array $categoryIds): void {
        Database::execute(
            "DELETE FROM employee_category_assignments WHERE employee_id = ? AND tenant_id = ?",
            [$employeeId, $tenantId]
        );
        foreach ($categoryIds as $catId) {
            $catId = (int) $catId;
            if ($catId <= 0) continue;
            Database::execute(
                "INSERT IGNORE INTO employee_category_assignments (employee_id, category_id, tenant_id) VALUES (?, ?, ?)",
                [$employeeId, $catId, $tenantId]
            );
        }
    }

    public static function getEmployeeCategories(int $employeeId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT ec.id, ec.name, ec.color
             FROM employee_categories ec
             JOIN employee_category_assignments eca ON eca.category_id = ec.id AND eca.tenant_id = ec.tenant_id
             WHERE eca.employee_id = ? AND eca.tenant_id = ? AND ec.is_active = 1
             ORDER BY ec.name ASC",
            [$employeeId, $tenantId]
        );
    }

    public static function getEmployeeCategoryIds(int $employeeId, int $tenantId): array {
        $rows = Database::fetchAll(
            "SELECT category_id FROM employee_category_assignments WHERE employee_id = ? AND tenant_id = ?",
            [$employeeId, $tenantId]
        );
        return array_map(fn($r) => (int) $r['category_id'], $rows);
    }

    /** Set (or clear, with null) the attendance-method override for a category. */
    public static function setAttendanceMethods(int $id, int $tenantId, ?array $methods): bool {
        return Database::execute(
            "UPDATE employee_categories SET attendance_methods = ? WHERE id = ? AND tenant_id = ?",
            [$methods !== null ? json_encode(array_values($methods)) : null, $id, $tenantId]
        ) >= 0;
    }

    public static function getEmployeesInCategory(int $categoryId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT e.* FROM employees e
             JOIN employee_category_assignments eca ON eca.employee_id = e.id AND eca.tenant_id = e.tenant_id
             WHERE eca.category_id = ? AND eca.tenant_id = ? AND e.status != 'terminated'
             ORDER BY e.name ASC",
            [$categoryId, $tenantId]
        );
    }
}
