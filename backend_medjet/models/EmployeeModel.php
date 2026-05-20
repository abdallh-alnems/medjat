<?php

final class EmployeeModel {
    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT e.*, s.start_time AS shift_start, s.end_time AS shift_end,
                    s.name AS shift_name, s.color AS shift_color
             FROM employees e
             LEFT JOIN shifts s ON s.id = e.shift_id
             WHERE e.id = ? AND e.tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function findByAdminId(int $adminId, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM employees WHERE admin_id = ? AND tenant_id = ? LIMIT 1",
            [$adminId, $tenantId]
        );
    }

    public static function create(int $tenantId, array $data): int {
        Database::execute(
            "INSERT INTO employees (tenant_id, branch_id, admin_id, name, phone, job_title,
             base_salary, hire_date, work_start_time, work_end_time, shift_id, national_id, status)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $data['branch_id'],
                $data['admin_id'] ?? null,
                $data['name'],
                $data['phone'] ?? null,
                $data['job_title'] ?? null,
                $data['base_salary'] ?? 0,
                $data['hire_date'] ?? date('Y-m-d'),
                $data['work_start_time'] ?? '09:00:00',
                $data['work_end_time'] ?? '17:00:00',
                $data['shift_id'] ?? null,
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
        $sql = "SELECT e.*, s.start_time AS shift_start, s.end_time AS shift_end,
                       s.name AS shift_name, s.color AS shift_color
                FROM employees e
                LEFT JOIN shifts s ON s.id = e.shift_id
                WHERE e.tenant_id = ? AND e.status != 'terminated'";
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

    public static function getReport(int $tenantId, ?int $branchId = null): array {
        $sql = "SELECT
                    e.id as employee_id,
                    e.name as employee_name,
                    e.job_title,
                    e.phone,
                    e.base_salary,
                    e.hire_date,
                    e.status,
                    b.name as branch_name,
                    s.name as shift_name,
                    COALESCE(SUM(CASE WHEN a.status = 'present' AND a.late_minutes = 0 THEN 1 END), 0) as days_present,
                    COALESCE(SUM(CASE WHEN a.status = 'present' AND a.late_minutes > 0 THEN 1 END), 0) as days_late,
                    COALESCE(SUM(CASE WHEN a.status = 'absent' THEN 1 END), 0) as days_absent,
                    COALESCE(SUM(CASE WHEN a.status = 'leave' THEN 1 END), 0) as days_leave,
                    COALESCE(SUM(a.worked_minutes), 0) as total_minutes_worked,
                    DATE_FORMAT(NOW(), '%Y-%m') as current_month
                FROM employees e
                LEFT JOIN branches b ON b.id = e.branch_id
                LEFT JOIN shifts s ON s.id = e.shift_id
                LEFT JOIN attendance a ON a.employee_id = e.id
                    AND DATE_FORMAT(a.date, '%Y-%m') = DATE_FORMAT(NOW(), '%Y-%m')
                WHERE e.tenant_id = ? AND e.status != 'terminated'";
        $params = [$tenantId];
        if ($branchId !== null) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }
        $sql .= " GROUP BY e.id ORDER BY e.name ASC";
        return Database::fetchAll($sql, $params);
    }

    public static function getReportSummary(int $tenantId, ?int $branchId = null): array {
        $sql = "SELECT
                    COUNT(*) as total_employees,
                    COUNT(CASE WHEN status = 'active' THEN 1 END) as active_count,
                    COUNT(CASE WHEN status = 'on_leave' THEN 1 END) as on_leave_count,
                    COUNT(CASE WHEN status = 'pending_activation' THEN 1 END) as pending_count,
                    COUNT(CASE WHEN status = 'suspended' THEN 1 END) as suspended_count,
                    COALESCE(SUM(base_salary), 0) as total_salaries,
                    COUNT(DISTINCT branch_id) as branch_count
                FROM employees
                WHERE tenant_id = ? AND status != 'terminated'";
        $params = [$tenantId];
        if ($branchId !== null) {
            $sql .= " AND branch_id = ?";
            $params[] = $branchId;
        }
        return Database::fetchOne($sql, $params) ?: [
            'total_employees' => 0,
            'active_count' => 0,
            'on_leave_count' => 0,
            'pending_count' => 0,
            'suspended_count' => 0,
            'total_salaries' => 0,
            'branch_count' => 0,
        ];
    }
}
