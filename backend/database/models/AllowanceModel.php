<?php

/**
 * Fixed monthly allowances per employee (housing, transport, food…). Each row
 * is active over [start_month, end_month] (inclusive; end_month NULL =
 * ongoing) and emitted by PayrollCalculator as a bonus line in every month
 * within that range, so payroll math keeps using the existing bonuses path.
 *
 * Distinct from manual bonuses (one-off, single month).
 */
final class AllowanceModel {
    /** Predefined types — the UI offers these but `type` is a free string for custom keys. */
    public const TYPES = ['housing', 'transport', 'food', 'communication', 'other'];

    public static function listForEmployee(int $employeeId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM employee_allowances
             WHERE employee_id = ? AND tenant_id = ?
             ORDER BY start_month DESC, id DESC",
            [$employeeId, $tenantId]
        );
    }

    /** Allowances active during [$month] for one employee (used by payroll calc). */
    public static function getActiveForEmployeeMonth(int $employeeId, string $month, int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM employee_allowances
             WHERE employee_id = ? AND tenant_id = ?
               AND start_month <= ?
               AND (end_month IS NULL OR end_month >= ?)
             ORDER BY type ASC, id ASC",
            [$employeeId, $tenantId, $month, $month]
        );
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM employee_allowances WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function create(
        int $tenantId,
        int $employeeId,
        string $type,
        float $amount,
        string $startMonth,
        ?string $endMonth,
        ?string $label,
        int $createdBy
    ): int {
        Database::execute(
            "INSERT INTO employee_allowances
                (tenant_id, employee_id, type, label, amount, start_month, end_month, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            [$tenantId, $employeeId, $type, $label, $amount, $startMonth, $endMonth, $createdBy]
        );
        return (int) Database::lastInsertId();
    }

    public static function update(
        int $id,
        int $tenantId,
        string $type,
        float $amount,
        string $startMonth,
        ?string $endMonth,
        ?string $label
    ): bool {
        return Database::execute(
            "UPDATE employee_allowances
             SET type = ?, label = ?, amount = ?, start_month = ?, end_month = ?
             WHERE id = ? AND tenant_id = ?",
            [$type, $label, $amount, $startMonth, $endMonth, $id, $tenantId]
        ) > 0;
    }

    public static function delete(int $id, int $tenantId): bool {
        return Database::execute(
            "DELETE FROM employee_allowances WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }

    /** Translated display label: explicit `label` wins, else translated `type`. */
    public static function displayLabel(array $allowance): string {
        $label = trim((string) ($allowance['label'] ?? ''));
        if ($label !== '') return $label;
        switch ($allowance['type']) {
            case 'housing':        return 'بدل سكن';
            case 'transport':      return 'بدل مواصلات';
            case 'food':           return 'بدل مأكل';
            case 'communication':  return 'بدل اتصالات';
            case 'other':          return 'بدل';
            default:               return (string) $allowance['type'];
        }
    }
}
