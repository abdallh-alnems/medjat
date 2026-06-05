<?php

final class BreakRequestModel
{
    public static function create(
        int $tenantId, int $employeeId, string $date,
        string $startTime, string $endTime, int $durationMinutes,
        string $type, ?string $reason
    ): int {
        Database::execute(
            "INSERT INTO break_requests
                (tenant_id, employee_id, date, start_time, end_time, duration_minutes, type, reason, status)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending')",
            [$tenantId, $employeeId, $date, $startTime, $endTime, $durationMinutes, $type, $reason]
        );
        return (int) Database::lastInsertId();
    }

    public static function find(int $id, int $tenantId): ?array
    {
        return Database::fetchOne(
            "SELECT * FROM break_requests WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function listForEmployee(int $employeeId, int $tenantId, ?string $status = null): array
    {
        $sql = "SELECT * FROM break_requests WHERE employee_id = ? AND tenant_id = ?";
        $params = [$employeeId, $tenantId];
        if ($status !== null) {
            $sql .= " AND status = ?";
            $params[] = $status;
        }
        $sql .= " ORDER BY date DESC, start_time DESC, id DESC";
        return Database::fetchAll($sql, $params);
    }

    public static function listForManager(
        int $tenantId, ?int $branchId = null, ?string $status = null,
        ?string $from = null, ?string $to = null
    ): array {
        $sql = "SELECT br.*, e.name AS employee_name, e.branch_id
                FROM break_requests br
                JOIN employees e ON e.id = br.employee_id
                WHERE br.tenant_id = ?";
        $params = [$tenantId];
        if ($branchId !== null) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }
        if ($status !== null) {
            $sql .= " AND br.status = ?";
            $params[] = $status;
        }
        if ($from !== null) {
            $sql .= " AND br.date >= ?";
            $params[] = $from;
        }
        if ($to !== null) {
            $sql .= " AND br.date <= ?";
            $params[] = $to;
        }
        $sql .= " ORDER BY br.date DESC, br.start_time DESC, br.id DESC";
        return Database::fetchAll($sql, $params);
    }

    public static function approve(
        int $id, int $tenantId, int $adminId, ?string $note = null, bool $deductFromSalary = false
    ): void {
        Database::execute(
            "UPDATE break_requests
             SET status = 'approved', decided_by = ?, decided_at = NOW(), decision_note = ?,
                 deduct_from_salary = ?
             WHERE id = ? AND tenant_id = ? AND status = 'pending'",
            [$adminId, $note, $deductFromSalary ? 1 : 0, $id, $tenantId]
        );
    }

    /**
     * Approved early-leave permissions flagged for hourly deduction, within a
     * date window. Used by the payroll calculator to subtract the early-leave
     * hours from the salary.
     */
    public static function approvedEarlyLeaveDeductions(
        int $employeeId, int $tenantId, string $from, string $to
    ): array {
        return Database::fetchAll(
            "SELECT id, date, start_time, end_time, duration_minutes
             FROM break_requests
             WHERE employee_id = ? AND tenant_id = ?
               AND type = 'early_leave' AND status = 'approved'
               AND deduct_from_salary = 1
               AND date >= ? AND date <= ?
             ORDER BY date ASC, start_time ASC",
            [$employeeId, $tenantId, $from, $to]
        );
    }

    public static function reject(int $id, int $tenantId, int $adminId, ?string $note = null): void
    {
        Database::execute(
            "UPDATE break_requests
             SET status = 'rejected', decided_by = ?, decided_at = NOW(), decision_note = ?
             WHERE id = ? AND tenant_id = ? AND status = 'pending'",
            [$adminId, $note, $id, $tenantId]
        );
    }

    public static function postpone(
        int $id, int $tenantId, int $adminId, ?string $note,
        ?string $sDate, ?string $sStart, ?string $sEnd
    ): void {
        Database::execute(
            "UPDATE break_requests
             SET status = 'postponed', decided_by = ?, decided_at = NOW(), decision_note = ?,
                 suggested_date = ?, suggested_start_time = ?, suggested_end_time = ?
             WHERE id = ? AND tenant_id = ? AND status = 'pending'",
            [$adminId, $note, $sDate, $sStart, $sEnd, $id, $tenantId]
        );
    }

    public static function cancel(int $id, int $employeeId, int $tenantId): void
    {
        Database::execute(
            "UPDATE break_requests SET status = 'cancelled'
             WHERE id = ? AND employee_id = ? AND tenant_id = ? AND status = 'pending'",
            [$id, $employeeId, $tenantId]
        );
    }

    public static function hasOverlap(
        int $employeeId, int $tenantId, string $date, string $start, string $end, ?int $excludeId = null
    ): bool {
        $sql = "SELECT id FROM break_requests
                WHERE employee_id = ? AND tenant_id = ? AND date = ?
                  AND status IN ('pending','approved')
                  AND start_time < ? AND end_time > ?";
        $params = [$employeeId, $tenantId, $date, $end, $start];
        if ($excludeId !== null) {
            $sql .= " AND id != ?";
            $params[] = $excludeId;
        }
        $sql .= " LIMIT 1";
        return Database::fetchOne($sql, $params) !== null;
    }
}
