<?php

/**
 * Work-suspension records ("موقوف عن العمل").
 *
 * An employee has at most one *active* suspension at a time. While it is
 * active the employee row carries status='suspended'; ending the suspension
 * restores `previous_status`. Payroll reads overlapping suspensions to deduct
 * pay for the suspended days according to `pay_mode`.
 */
final class EmployeeSuspensionModel {
    public const PAY_MODES = ['unpaid', 'partial', 'full'];

    /** Insert a new suspension and return its id. */
    public static function create(int $tenantId, int $employeeId, array $data, ?int $createdBy): int {
        Database::execute(
            "INSERT INTO employee_suspensions
                (tenant_id, employee_id, reason, pay_mode, pay_percentage,
                 start_date, end_date, previous_status, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                $tenantId,
                $employeeId,
                $data['reason'],
                $data['pay_mode'],
                $data['pay_percentage'] ?? null,
                $data['start_date'],
                $data['end_date'] ?? null,
                $data['previous_status'] ?? null,
                $createdBy,
            ]
        );
        return (int) Database::lastInsertId();
    }

    /** The currently-active suspension for an employee, or null. */
    public static function getActiveForEmployee(int $employeeId, int $tenantId): ?array {
        $row = Database::fetchOne(
            "SELECT * FROM employee_suspensions
             WHERE employee_id = ? AND tenant_id = ? AND status = 'active'
             ORDER BY start_date DESC, id DESC LIMIT 1",
            [$employeeId, $tenantId]
        );
        return $row ?: null;
    }

    /** Full suspension history for an employee (newest first). */
    public static function getByEmployee(int $employeeId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT s.*, c.name AS created_by_name, e.name AS ended_by_name
             FROM employee_suspensions s
             LEFT JOIN admins c ON c.id = s.created_by
             LEFT JOIN admins e ON e.id = s.ended_by
             WHERE s.employee_id = ? AND s.tenant_id = ?
             ORDER BY s.start_date DESC, s.id DESC",
            [$employeeId, $tenantId]
        );
    }

    /**
     * Suspensions (active or already ended) whose window overlaps the inclusive
     * range [$rangeStart, $rangeEnd]. Open-ended suspensions (end_date NULL) are
     * treated as running through $rangeEnd. Used by the payroll calculator.
     */
    public static function getOverlappingForPayroll(int $employeeId, int $tenantId, string $rangeStart, string $rangeEnd): array {
        return Database::fetchAll(
            "SELECT id, start_date, end_date, pay_mode, pay_percentage, status
             FROM employee_suspensions
             WHERE employee_id = ? AND tenant_id = ?
               AND start_date <= ?
               AND (end_date IS NULL OR end_date >= ?)
             ORDER BY start_date ASC",
            [$employeeId, $tenantId, $rangeEnd, $rangeStart]
        );
    }

    /** Mark a suspension ended. Does not touch the employee row. */
    public static function end(int $id, int $tenantId, ?int $endedBy, ?string $endNote): bool {
        return Database::execute(
            "UPDATE employee_suspensions
             SET status = 'ended', ended_at = NOW(), ended_by = ?, end_note = ?
             WHERE id = ? AND tenant_id = ? AND status = 'active'",
            [$endedBy, $endNote, $id, $tenantId]
        ) > 0;
    }

    /**
     * Definite suspensions whose end_date has passed but are still active.
     * Used to lazily auto-reactivate employees when their period elapses.
     */
    public static function dueForExpiry(int $tenantId, string $today): array {
        return Database::fetchAll(
            "SELECT id, employee_id, previous_status
             FROM employee_suspensions
             WHERE tenant_id = ? AND status = 'active'
               AND end_date IS NOT NULL AND end_date < ?",
            [$tenantId, $today]
        );
    }

    /**
     * Auto-end any definite suspensions that have elapsed and restore the
     * affected employees to their previous status. Called lazily from the
     * profile/list endpoints so reactivation works without a cron.
     */
    public static function reconcileExpired(int $tenantId, string $today): void {
        $due = self::dueForExpiry($tenantId, $today);
        foreach ($due as $row) {
            Database::execute(
                "UPDATE employee_suspensions SET status = 'ended', ended_at = NOW()
                 WHERE id = ? AND tenant_id = ? AND status = 'active'",
                [(int) $row['id'], $tenantId]
            );
            $restore = $row['previous_status'] ?: 'active';
            Database::execute(
                "UPDATE employees SET status = ?, updated_at = NOW()
                 WHERE id = ? AND tenant_id = ? AND status = 'suspended'",
                [$restore, (int) $row['employee_id'], $tenantId]
            );
        }
    }
}
