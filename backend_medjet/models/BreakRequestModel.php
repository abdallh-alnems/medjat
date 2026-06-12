<?php

final class BreakRequestModel
{
    public static function create(
        int $tenantId, int $employeeId, string $date,
        string $startTime, string $endTime, int $durationMinutes,
        string $type, ?string $reason, bool $deductFromSalary = false
    ): int {
        Database::execute(
            "INSERT INTO break_requests
                (tenant_id, employee_id, date, start_time, end_time, duration_minutes, type, deduct_from_salary, reason, status)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')",
            [$tenantId, $employeeId, $date, $startTime, $endTime, $durationMinutes, $type, $deductFromSalary ? 1 : 0, $reason]
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
        ?string $from = null, ?string $to = null,
        ?int $categoryId = null, ?string $search = null
    ): array {
        $sql = "SELECT br.*, e.name AS employee_name, e.branch_id,
                       a.name AS decided_by_name
                FROM break_requests br
                JOIN employees e ON e.id = br.employee_id
                LEFT JOIN admins a ON a.id = br.decided_by
                WHERE br.tenant_id = ?";
        $params = [$tenantId];
        if ($branchId !== null) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }
        if ($categoryId !== null) {
            $sql .= " AND EXISTS (SELECT 1 FROM employee_category_assignments eca
                                  WHERE eca.employee_id = e.id AND eca.category_id = ?)";
            $params[] = $categoryId;
        }
        if ($search !== null && $search !== '') {
            $sql .= " AND e.name LIKE ?";
            $params[] = '%' . $search . '%';
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
        // Newest-submitted first: order by when the request was added.
        $sql .= " ORDER BY br.created_at DESC, br.id DESC";
        return Database::fetchAll($sql, $params);
    }

    /** Count of still-pending permission requests for the tenant. */
    public static function countPending(int $tenantId): int
    {
        $row = Database::fetchOne(
            "SELECT COUNT(*) AS c FROM break_requests
             WHERE tenant_id = ? AND status = 'pending'",
            [$tenantId]
        );
        return (int) ($row['c'] ?? 0);
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
     * Approved permissions (any type) flagged for hourly deduction, within a
     * date window. Used by the payroll calculator to subtract the permission
     * hours from the salary.
     */
    public static function approvedHourlyDeductions(
        int $employeeId, int $tenantId, string $from, string $to
    ): array {
        return Database::fetchAll(
            "SELECT id, date, start_time, end_time, duration_minutes, type
             FROM break_requests
             WHERE employee_id = ? AND tenant_id = ?
               AND status = 'approved'
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

    /**
     * Employee accepts the manager's suggested alternative time: the request
     * adopts the suggested slot and becomes approved at that time. Returns true
     * if a postponed request was actually updated.
     */
    public static function acceptPostpone(
        int $id, int $employeeId, int $tenantId, int $durationMinutes
    ): bool {
        $affected = Database::execute(
            "UPDATE break_requests
                SET `date` = suggested_date,
                    start_time = suggested_start_time,
                    end_time = suggested_end_time,
                    duration_minutes = ?,
                    status = 'approved',
                    decided_at = NOW(),
                    suggested_date = NULL,
                    suggested_start_time = NULL,
                    suggested_end_time = NULL
              WHERE id = ? AND employee_id = ? AND tenant_id = ?
                AND status = 'postponed' AND suggested_date IS NOT NULL",
            [$durationMinutes, $id, $employeeId, $tenantId]
        );
        return $affected > 0;
    }

    /** Employee declines the suggested alternative time → request is cancelled. */
    public static function rejectPostpone(int $id, int $employeeId, int $tenantId): bool
    {
        $affected = Database::execute(
            "UPDATE break_requests
                SET status = 'cancelled',
                    decision_note = 'رفض الموظف الوقت البديل المقترح'
              WHERE id = ? AND employee_id = ? AND tenant_id = ? AND status = 'postponed'",
            [$id, $employeeId, $tenantId]
        );
        return $affected > 0;
    }

    public static function cancel(int $id, int $employeeId, int $tenantId): void
    {
        Database::execute(
            "UPDATE break_requests SET status = 'cancelled'
             WHERE id = ? AND employee_id = ? AND tenant_id = ? AND status = 'pending'",
            [$id, $employeeId, $tenantId]
        );
    }

    /**
     * Auto-cancel still-pending permissions for an employee once they check out:
     * any request whose day is today or earlier can no longer be acted on, so it
     * is cancelled to avoid being approved after the shift has ended.
     * Returns the number of cancelled requests.
     */
    public static function cancelPendingOnCheckOut(int $employeeId, int $tenantId): int
    {
        return Database::execute(
            "UPDATE break_requests
                SET status = 'cancelled',
                    decision_note = 'أُلغي تلقائياً بعد تسجيل الانصراف'
             WHERE employee_id = ? AND tenant_id = ?
               AND status = 'pending'
               AND `date` <= CURDATE()",
            [$employeeId, $tenantId]
        );
    }

    /**
     * Auto-cancel any pending permission whose window (date + end_time) has
     * already passed. A request can't logically stay "pending" after its time
     * is gone, so it's cancelled before the list is shown. Pass an employee id
     * to scope it; otherwise the whole tenant is swept. Returns rows affected.
     */
    public static function expirePastPending(int $tenantId, ?int $employeeId = null): int
    {
        $sql = "UPDATE break_requests
                   SET status = 'cancelled',
                       decision_note = 'انتهى وقت الإذن قبل البتّ فيه'
                 WHERE tenant_id = ?
                   AND status = 'pending'
                   AND TIMESTAMP(`date`, end_time) < NOW()";
        $params = [$tenantId];
        if ($employeeId !== null) {
            $sql .= " AND employee_id = ?";
            $params[] = $employeeId;
        }
        return Database::execute($sql, $params);
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
