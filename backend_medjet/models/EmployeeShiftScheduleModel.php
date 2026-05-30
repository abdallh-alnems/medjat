<?php

/**
 * Weekly rotating shift roster. One row per employee per day; shift_id NULL = rest day.
 * Rows are 'draft' while a manager edits the week and 'published' once confirmed —
 * only published rows drive attendance (see findEffective + AttendanceModel).
 */
final class EmployeeShiftScheduleModel {
    /** Active employees a roster can be built for (no pagination — the grid needs them all). */
    public static function getRosterEmployees(int $tenantId, ?int $branchId = null): array {
        $sql = "SELECT e.id, e.name, e.job_title, e.branch_id, b.name AS branch_name,
                       e.shift_type, e.shift_id
                FROM employees e
                LEFT JOIN branches b ON b.id = e.branch_id
                WHERE e.tenant_id = ? AND e.status NOT IN ('terminated', 'pending_activation')";
        $params = [$tenantId];
        if ($branchId !== null) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }
        $sql .= " ORDER BY e.name ASC";
        return Database::fetchAll($sql, $params);
    }

    /** All schedule cells in a date range, with the joined shift details for rendering. */
    public static function getCells(int $tenantId, string $startDate, string $endDate, ?int $branchId = null): array {
        $sql = "SELECT ess.id, ess.employee_id, ess.shift_id, ess.work_date, ess.status,
                       s.name AS shift_name, s.start_time, s.end_time, s.color
                FROM employee_shift_schedule ess
                JOIN employees e ON e.id = ess.employee_id
                LEFT JOIN shifts s ON s.id = ess.shift_id
                WHERE ess.tenant_id = ? AND ess.work_date BETWEEN ? AND ?
                  AND e.status != 'terminated'";
        $params = [$tenantId, $startDate, $endDate];
        if ($branchId !== null) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }
        $sql .= " ORDER BY ess.work_date ASC";
        return Database::fetchAll($sql, $params);
    }

    /**
     * Set the same shift (or rest, when shiftId is null) for many employees across many
     * dates. Editing always resets the cell to 'draft' so it must be re-published.
     */
    public static function bulkAssign(
        int $tenantId,
        array $employeeIds,
        array $dates,
        ?int $shiftId,
        int $createdBy
    ): int {
        $employeeIds = array_values(array_unique(array_map('intval', $employeeIds)));
        if (empty($employeeIds) || empty($dates)) return 0;

        $count = 0;
        foreach ($employeeIds as $employeeId) {
            foreach ($dates as $date) {
                Database::execute(
                    "INSERT INTO employee_shift_schedule
                        (tenant_id, employee_id, shift_id, work_date, status, created_by)
                     VALUES (?, ?, ?, ?, 'draft', ?)
                     ON DUPLICATE KEY UPDATE
                        shift_id = VALUES(shift_id),
                        status = 'draft',
                        created_by = VALUES(created_by)",
                    [$tenantId, $employeeId, $shiftId, $date, $createdBy]
                );
                $count++;
            }
        }
        return $count;
    }

    /** Remove a single cell (back to "unscheduled" — attendance falls back to static shift). */
    public static function clearCell(int $tenantId, int $employeeId, string $workDate): void {
        Database::execute(
            "DELETE FROM employee_shift_schedule
             WHERE tenant_id = ? AND employee_id = ? AND work_date = ?",
            [$tenantId, $employeeId, $workDate]
        );
    }

    /** Copy one week's cells into another week as drafts (the "copy previous week" button). */
    public static function copyWeek(
        int $tenantId,
        string $fromStart,
        string $fromEnd,
        string $toStart,
        ?int $branchId,
        int $createdBy
    ): int {
        $source = self::getCells($tenantId, $fromStart, $fromEnd, $branchId);
        if (empty($source)) return 0;

        $offsetDays = (int) ((strtotime($toStart) - strtotime($fromStart)) / 86400);
        $count = 0;
        foreach ($source as $cell) {
            $targetDate = date('Y-m-d', strtotime($cell['work_date'] . " +{$offsetDays} days"));
            Database::execute(
                "INSERT INTO employee_shift_schedule
                    (tenant_id, employee_id, shift_id, work_date, status, created_by)
                 VALUES (?, ?, ?, ?, 'draft', ?)
                 ON DUPLICATE KEY UPDATE
                    shift_id = VALUES(shift_id),
                    status = 'draft',
                    created_by = VALUES(created_by)",
                [$tenantId, (int) $cell['employee_id'], $cell['shift_id'], $targetDate, $createdBy]
            );
            $count++;
        }
        return $count;
    }

    /** Mark every draft cell in the week as published, making it the attendance source. */
    public static function publishWeek(int $tenantId, string $startDate, string $endDate, ?int $branchId = null): int {
        if ($branchId === null) {
            return Database::execute(
                "UPDATE employee_shift_schedule
                 SET status = 'published'
                 WHERE tenant_id = ? AND work_date BETWEEN ? AND ? AND status = 'draft'",
                [$tenantId, $startDate, $endDate]
            );
        }
        return Database::execute(
            "UPDATE employee_shift_schedule ess
             JOIN employees e ON e.id = ess.employee_id
             SET ess.status = 'published'
             WHERE ess.tenant_id = ? AND ess.work_date BETWEEN ? AND ?
               AND ess.status = 'draft' AND e.branch_id = ?",
            [$tenantId, $startDate, $endDate, $branchId]
        );
    }

    /**
     * The published shift an employee is expected on for a given date, with its times.
     * Used by attendance to compute late/overtime. Returns null when nothing is published
     * (caller falls back to the static shift), and a row with NULL start_time on a rest day.
     */
    public static function findEffective(int $employeeId, int $tenantId, string $date): ?array {
        return Database::fetchOne(
            "SELECT ess.shift_id, s.start_time, s.end_time
             FROM employee_shift_schedule ess
             LEFT JOIN shifts s ON s.id = ess.shift_id
             WHERE ess.employee_id = ? AND ess.tenant_id = ? AND ess.work_date = ?
               AND ess.status = 'published'
             LIMIT 1",
            [$employeeId, $tenantId, $date]
        );
    }
}
