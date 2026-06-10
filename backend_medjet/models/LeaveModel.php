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

    /**
     * Convert an existing leave into an absence. Every calendar day in the
     * leave's range is set to 'absent' (creating/updating the attendance row,
     * which makes the day deductible), then the leave record itself is removed
     * so it no longer counts toward the annual-leave balance.
     *
     * @return array{employee_id:int, days:int} Summary for the caller.
     */
    public static function convertToAbsence(int $leaveId, int $tenantId, int $adminId, ?string $reason = null): array {
        $leave = Database::fetchOne(
            "SELECT id, employee_id,
                    DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
                    DATE_FORMAT(end_date, '%Y-%m-%d') AS end_date
             FROM leaves WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$leaveId, $tenantId]
        );
        if (!$leave) {
            throw new RuntimeException('Leave not found');
        }

        $employee = EmployeeModel::findById((int) $leave['employee_id'], $tenantId);
        if (!$employee) {
            throw new RuntimeException('Employee not found');
        }

        $cursor = new DateTime($leave['start_date']);
        $end = new DateTime($leave['end_date']);
        $note = $reason ?? 'Converted from leave';
        $days = 0;

        while ($cursor <= $end) {
            AttendanceModel::setDayStatus(
                $employee,
                $tenantId,
                $cursor->format('Y-m-d'),
                'absent',
                null,
                null,
                null,
                $note,
                $adminId
            );
            $days++;
            $cursor->modify('+1 day');
        }

        // The days are now absences; drop the leave so the balance stays correct.
        Database::execute(
            "DELETE FROM leaves WHERE id = ? AND tenant_id = ?",
            [$leaveId, $tenantId]
        );

        return ['employee_id' => (int) $leave['employee_id'], 'days' => $days];
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

    public static function getActiveLeaveTypeForEmployee(int $employeeId, string $date, int $tenantId): ?string {
        $row = Database::fetchOne(
            "SELECT type, reason FROM leaves WHERE employee_id = ? AND date = ? AND tenant_id = ? AND status = 'approved' LIMIT 1",
            [$employeeId, $date, $tenantId]
        );
        if ($row === null) return null;
        $reason = trim((string) ($row['reason'] ?? ''));
        if ($reason !== '') return $reason;
        return $row['type'] ?? null;
    }

    public static function hasOverlap(int $employeeId, int $tenantId, string $start, string $end, ?int $excludeId = null): bool {
        $sql = "SELECT id FROM leaves
                WHERE employee_id = ? AND tenant_id = ?
                  AND status IN ('approved','pending')
                  AND start_date <= ? AND end_date >= ?";
        $params = [$employeeId, $tenantId, $end, $start];
        if ($excludeId !== null) {
            $sql .= ' AND id != ?';
            $params[] = $excludeId;
        }
        $sql .= ' LIMIT 1';
        return Database::fetchOne($sql, $params) !== null;
    }

    /**
     * Dynamic annual leave balance for an employee in a given year.
     * entitlement = employees.annual_leave_days ?? tenants.default_annual_leave_days (default 21).
     * carried     = leave_year_balances.carried_over_days for that year (0 when no row).
     * total       = entitlement + carried; remaining = max(0, total - used).
     */
    public static function getBalance(int $employeeId, int $tenantId, int $year): array {
        $entRow = Database::fetchOne(
            "SELECT COALESCE(e.annual_leave_days, t.default_annual_leave_days, 21) AS entitlement_days
             FROM employees e
             JOIN tenants t ON t.id = e.tenant_id
             WHERE e.id = ? AND e.tenant_id = ? LIMIT 1",
            [$employeeId, $tenantId]
        );
        $entitlementDays = (int) ($entRow['entitlement_days'] ?? 21);

        $carryRow = Database::fetchOne(
            "SELECT carried_over_days FROM leave_year_balances
             WHERE employee_id = ? AND tenant_id = ? AND year = ? LIMIT 1",
            [$employeeId, $tenantId, $year]
        );
        $carriedOverDays = (int) ($carryRow['carried_over_days'] ?? 0);

        $row = Database::fetchOne(
            "SELECT COALESCE(SUM(DATEDIFF(end_date, start_date) + 1), 0) as used_days
             FROM leaves
             WHERE employee_id = ? AND tenant_id = ? AND type = 'annual'
               AND status = 'approved' AND YEAR(date) = ?",
            [$employeeId, $tenantId, $year]
        );
        $usedDays = (int) ($row['used_days'] ?? 0);
        $totalDays = $entitlementDays + $carriedOverDays;

        return [
            'year' => $year,
            'entitlement_days' => $entitlementDays,
            'carried_over_days' => $carriedOverDays,
            'total_days' => $totalDays,
            'used_days' => $usedDays,
            'remaining_days' => max(0, $totalDays - $usedDays),
        ];
    }

    /**
     * Carry remaining annual balance from $fromYear into $fromYear + 1 for every active employee.
     * carried = min(remaining, tenants.leave_carryover_max_days); 0 when carryover is disabled (NULL).
     * Upserts one leave_year_balances row per employee for the target year, inside a transaction.
     *
     * @return array{from_year:int, to_year:int, processed:int, carryover_max:?int}
     */
    public static function rolloverYear(int $tenantId, int $fromYear): array {
        $tenant = Database::fetchOne(
            "SELECT default_annual_leave_days, leave_carryover_max_days FROM tenants WHERE id = ? LIMIT 1",
            [$tenantId]
        );
        if (!$tenant) {
            throw new RuntimeException('Tenant not found');
        }
        $carryoverMax = $tenant['leave_carryover_max_days'] !== null
            ? (int) $tenant['leave_carryover_max_days']
            : null;
        $toYear = $fromYear + 1;

        $employees = Database::fetchAll(
            "SELECT id FROM employees WHERE tenant_id = ? AND status != 'terminated'",
            [$tenantId]
        );

        $con = Database::getInstance();
        $con->beginTransaction();
        try {
            $processed = 0;
            foreach ($employees as $emp) {
                $employeeId = (int) $emp['id'];
                $balance = self::getBalance($employeeId, $tenantId, $fromYear);
                $remaining = (int) $balance['remaining_days'];
                $carried = $carryoverMax === null ? 0 : min($remaining, $carryoverMax);

                // Entitlement for the new year (per-employee override else tenant default).
                $entRow = Database::fetchOne(
                    "SELECT COALESCE(annual_leave_days, ?) AS entitlement_days
                     FROM employees WHERE id = ? AND tenant_id = ? LIMIT 1",
                    [(int) $tenant['default_annual_leave_days'], $employeeId, $tenantId]
                );
                $entitlement = (int) ($entRow['entitlement_days'] ?? $tenant['default_annual_leave_days']);

                Database::execute(
                    "INSERT INTO leave_year_balances (tenant_id, employee_id, year, entitlement_days, carried_over_days)
                     VALUES (?, ?, ?, ?, ?)
                     ON DUPLICATE KEY UPDATE entitlement_days = VALUES(entitlement_days),
                                             carried_over_days = VALUES(carried_over_days)",
                    [$tenantId, $employeeId, $toYear, $entitlement, $carried]
                );
                $processed++;
            }
            $con->commit();
        } catch (Exception $e) {
            $con->rollBack();
            throw $e;
        }

        return [
            'from_year' => $fromYear,
            'to_year' => $toYear,
            'processed' => $processed,
            'carryover_max' => $carryoverMax,
        ];
    }

    public static function countPending(int $tenantId, ?int $branchId = null): int {
        $sql = "SELECT COUNT(*) AS c FROM leaves l
                JOIN employees e ON e.id = l.employee_id
                WHERE l.tenant_id = ? AND l.status = 'pending'";
        $params = [$tenantId];
        if ($branchId) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }
        return (int) (Database::fetchOne($sql, $params)['c'] ?? 0);
    }

    /**
     * The employee's own leave requests, newest first. Used by the employee app
     * so a worker can track requests still awaiting a manager's decision.
     */
    public static function getByEmployee(int $employeeId, int $tenantId, ?string $status = null, int $limit = 50): array {
        $sql = "SELECT id, type,
                       DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
                       DATE_FORMAT(end_date, '%Y-%m-%d') AS end_date,
                       (DATEDIFF(end_date, start_date) + 1) AS days,
                       reason, status, rejection_reason,
                       DATE_FORMAT(created_at, '%Y-%m-%d') AS created_at
                FROM leaves
                WHERE employee_id = ? AND tenant_id = ?";
        $params = [$employeeId, $tenantId];
        if ($status) {
            $sql .= " AND status = ?";
            $params[] = $status;
        }
        $sql .= " ORDER BY created_at DESC, id DESC LIMIT ?";
        $params[] = $limit;
        return Database::fetchAll($sql, $params);
    }

    /** How many leave requests the employee currently has awaiting a decision. */
    public static function countPendingForEmployee(int $employeeId, int $tenantId): int {
        $row = Database::fetchOne(
            "SELECT COUNT(*) AS c FROM leaves
             WHERE employee_id = ? AND tenant_id = ? AND status = 'pending'",
            [$employeeId, $tenantId]
        );
        return (int) ($row['c'] ?? 0);
    }

    /** Fetch a leave only if it belongs to the employee and is still pending. */
    public static function findOwnedPending(int $leaveId, int $employeeId, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT id, employee_id, type,
                    DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
                    DATE_FORMAT(end_date, '%Y-%m-%d') AS end_date,
                    reason, status
             FROM leaves
             WHERE id = ? AND employee_id = ? AND tenant_id = ? AND status = 'pending'
             LIMIT 1",
            [$leaveId, $employeeId, $tenantId]
        );
    }

    /** Delete a pending leave owned by the employee. Returns true if a row was removed. */
    public static function cancelOwn(int $leaveId, int $employeeId, int $tenantId): bool {
        $affected = Database::execute(
            "DELETE FROM leaves
             WHERE id = ? AND employee_id = ? AND tenant_id = ? AND status = 'pending'",
            [$leaveId, $employeeId, $tenantId]
        );
        return $affected > 0;
    }

    /** Update a pending leave owned by the employee. Returns true if it was updated. */
    public static function updateOwn(
        int $leaveId,
        int $employeeId,
        int $tenantId,
        string $type,
        string $startDate,
        string $endDate,
        ?string $reason
    ): bool {
        Database::execute(
            "UPDATE leaves
             SET type = ?, date = ?, start_date = ?, end_date = ?, reason = ?
             WHERE id = ? AND employee_id = ? AND tenant_id = ? AND status = 'pending'",
            [$type, $startDate, $startDate, $endDate, $reason, $leaveId, $employeeId, $tenantId]
        );
        return true;
    }

    public static function getByTenant(
        int $tenantId,
        int $page = 1,
        int $limit = 20,
        ?string $status = null,
        ?int $branchId = null,
        ?int $categoryId = null,
        ?string $search = null
    ): array {
        $sql = "SELECT l.*,
                       e.name as employee_name,
                       e.branch_id,
                       b.name as branch_name,
                       ap.name as approved_by_name,
                       rj.name as rejected_by_name,
                       (SELECT GROUP_CONCAT(eca.category_id)
                          FROM employee_category_assignments eca
                          WHERE eca.employee_id = e.id) AS category_ids
                FROM leaves l
                JOIN employees e ON e.id = l.employee_id
                LEFT JOIN branches b ON b.id = e.branch_id
                LEFT JOIN admins ap ON ap.id = l.approved_by
                LEFT JOIN admins rj ON rj.id = l.rejected_by
                WHERE l.tenant_id = ?";
        $params = [$tenantId];

        if ($status) {
            $sql .= " AND l.status = ?";
            $params[] = $status;
        }
        if ($branchId !== null) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }
        if ($categoryId !== null) {
            $sql .= " AND EXISTS (SELECT 1 FROM employee_category_assignments eca
                                  WHERE eca.employee_id = e.id AND eca.category_id = ?)";
            $params[] = $categoryId;
        }
        if ($search !== null && trim($search) !== '') {
            $sql .= " AND e.name LIKE ?";
            $params[] = '%' . trim($search) . '%';
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
