<?php

final class LeaveModel {
    public static function apply(int $employeeId, int $tenantId, string $date, string $type, ?string $reason = null, ?string $startDate = null, ?string $endDate = null): int {
        Database::execute(
            "INSERT INTO leaves (tenant_id, employee_id, date, start_date, end_date, type, reason, status)
             VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')",
            [$tenantId, $employeeId, $date, $startDate ?? $date, $endDate ?? $date, $type, $reason]
        );
        return (int) Database::lastInsertId();
    }

    public static function approve(int $leaveId, int $tenantId, int $approvedBy): void {
        Database::execute(
            "UPDATE leaves SET status = 'approved', approved_by = ?, approved_at = NOW() WHERE id = ? AND tenant_id = ?",
            [$approvedBy, $leaveId, $tenantId]
        );
    }

    public static function reject(int $leaveId, int $tenantId, int $rejectedBy, ?string $rejectionReason = null): void {
        Database::execute(
            "UPDATE leaves SET status = 'rejected', rejected_by = ?, rejection_reason = ? WHERE id = ? AND tenant_id = ?",
            [$rejectedBy, $rejectionReason, $leaveId, $tenantId]
        );
    }

    public static function convertAbsenceToLeave(int $employeeId, int $tenantId, string $date, string $type, string $reason, int $convertedBy): void {
        $con = Database::getInstance();
        $con->beginTransaction();
        try {
            Database::execute(
                "UPDATE attendance SET status = 'leave' WHERE employee_id = ? AND date = ? AND tenant_id = ?",
                [$employeeId, $date, $tenantId]
            );

            Database::execute(
                "INSERT INTO leaves (tenant_id, employee_id, date, start_date, end_date, type, reason, status, approved_by, approved_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, 'approved', ?, NOW())",
                [$tenantId, $employeeId, $date, $date, $date, $type, $reason, $convertedBy]
            );

            $con->commit();
        } catch (Exception $e) {
            $con->rollBack();
            throw $e;
        }
    }

    public static function createRecurring(int $tenantId, ?int $branchId, string $dayOfWeek, string $type, ?string $reason = null): int {
        Database::execute(
            "INSERT INTO recurring_leaves (tenant_id, branch_id, day_of_week, type, reason, is_active)
             VALUES (?, ?, ?, ?, ?, 1)",
            [$tenantId, $branchId, $dayOfWeek, $type, $reason]
        );
        return (int) Database::lastInsertId();
    }

    public static function isEmployeeOnLeave(int $employeeId, string $date, int $tenantId): bool {
        $row = Database::fetchOne(
            "SELECT id FROM leaves WHERE employee_id = ? AND date = ? AND tenant_id = ? AND status = 'approved' LIMIT 1",
            [$employeeId, $date, $tenantId]
        );
        return $row !== null;
    }

    public static function getBalance(int $employeeId, int $tenantId, int $year): array {
        $used = Database::fetchOne(
            "SELECT COUNT(*) as count FROM leaves WHERE employee_id = ? AND tenant_id = ? AND status = 'approved' AND YEAR(date) = ?",
            [$employeeId, $tenantId, $year]
        );

        return [
            'year' => $year,
            'used' => (int) ($used['count'] ?? 0),
            'remaining' => max(0, 21 - (int) ($used['count'] ?? 0)),
            'total_annual' => 21,
        ];
    }

    public static function getByTenant(int $tenantId, int $page = 1, int $limit = 20, ?string $status = null): array {
        $sql = "SELECT l.*, e.name as employee_name FROM leaves l
                JOIN employees e ON e.id = l.employee_id
                WHERE l.tenant_id = ?";
        $params = [$tenantId];

        if ($status) {
            $sql .= " AND l.status = ?";
            $params[] = $status;
        }

        $offset = ($page - 1) * $limit;
        $sql .= " ORDER BY l.created_at DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;

        return ['items' => Database::fetchAll($sql, $params), 'page' => $page];
    }

    public static function getReportByRange(
        int $tenantId,
        string $startDate,
        string $endDate,
        ?int $branchId = null,
        ?string $status = null
    ): array {
        $sql = "SELECT
                    l.id,
                    l.employee_id,
                    e.name as employee_name,
                    b.name as branch_name,
                    l.type,
                    l.start_date,
                    l.end_date,
                    l.reason,
                    l.status,
                    l.created_at
                FROM leaves l
                JOIN employees e ON e.id = l.employee_id
                LEFT JOIN branches b ON b.id = e.branch_id
                WHERE l.tenant_id = ? AND l.date BETWEEN ? AND ?";
        $params = [$tenantId, $startDate, $endDate];
        if ($branchId !== null) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }
        if ($status !== null) {
            $sql .= " AND l.status = ?";
            $params[] = $status;
        }
        $sql .= " ORDER BY l.date DESC";
        return Database::fetchAll($sql, $params);
    }

    public static function getReportSummary(
        int $tenantId,
        string $startDate,
        string $endDate,
        ?int $branchId = null
    ): array {
        $sql = "SELECT
                    COUNT(*) as total_leaves,
                    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_count,
                    COUNT(CASE WHEN status = 'approved' THEN 1 END) as approved_count,
                    COUNT(CASE WHEN status = 'rejected' THEN 1 END) as rejected_count,
                    COUNT(CASE WHEN type = 'annual' THEN 1 END) as annual_count,
                    COUNT(CASE WHEN type = 'sick' THEN 1 END) as sick_count,
                    COUNT(CASE WHEN type = 'personal' THEN 1 END) as personal_count,
                    COUNT(CASE WHEN type = 'unpaid' THEN 1 END) as unpaid_count,
                    COUNT(CASE WHEN type = 'converted_from_absence' THEN 1 END) as converted_count,
                    COUNT(DISTINCT employee_id) as employees_on_leave
                FROM leaves
                WHERE tenant_id = ? AND date BETWEEN ? AND ?";
        $params = [$tenantId, $startDate, $endDate];
        if ($branchId !== null) {
            $sql .= " AND employee_id IN (SELECT id FROM employees WHERE branch_id = ?)";
            $params[] = $branchId;
        }
        return Database::fetchOne($sql, $params) ?: [
            'total_leaves' => 0,
            'pending_count' => 0,
            'approved_count' => 0,
            'rejected_count' => 0,
            'annual_count' => 0,
            'sick_count' => 0,
            'personal_count' => 0,
            'unpaid_count' => 0,
            'converted_count' => 0,
            'employees_on_leave' => 0,
        ];
    }
}
