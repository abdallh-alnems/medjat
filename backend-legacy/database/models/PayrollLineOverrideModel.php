<?php

/**
 * Per-line payroll overrides: edit the amount of, or remove, any single
 * computed payroll line (absence, late, loan, insurance, tax, overtime…) for
 * one employee in one month. A line is keyed by a stable hash of its
 * (type | date | description) so the override re-attaches on every recalc.
 *
 * @see PayrollCalculator::applyLineOverrides() which consumes getMap()
 * @see app/payroll/override_line.php
 */
final class PayrollLineOverrideModel {

    /** Stable identity for a computed line. Must match the calculator. */
    public static function hash(string $type, ?string $date, string $desc): string {
        return sha1($type . '|' . ($date ?? '') . '|' . $desc);
    }

    /**
     * All overrides for an employee/month, keyed by "kind|hash" for O(1)
     * lookup while the calculator walks the line list.
     *
     * @return array<string,array{waived:bool,amount:?float}>
     */
    public static function getMap(int $employeeId, string $month, int $tenantId): array {
        $rows = Database::fetchAll(
            "SELECT line_kind, line_hash, waived, override_amount
               FROM payroll_line_overrides
              WHERE employee_id = ? AND month = ? AND tenant_id = ?",
            [$employeeId, $month, $tenantId]
        );
        $map = [];
        foreach ($rows as $r) {
            $map[$r['line_kind'] . '|' . $r['line_hash']] = [
                'waived' => (int) $r['waived'] === 1,
                'amount' => $r['override_amount'] !== null ? (float) $r['override_amount'] : null,
            ];
        }
        return $map;
    }

    /**
     * Create or update an override for one line. Pass $waived=true to remove
     * the line, or $amount to replace its value (mutually exclusive).
     */
    public static function upsert(
        int $tenantId,
        int $employeeId,
        string $month,
        string $kind,
        string $type,
        ?string $date,
        string $desc,
        bool $waived,
        ?float $amount,
        ?string $reason,
        ?int $createdBy
    ): void {
        $hash = self::hash($type, $date, $desc);
        Database::execute(
            "INSERT INTO payroll_line_overrides
                (tenant_id, employee_id, month, line_kind, line_type, line_date,
                 line_desc, line_hash, waived, override_amount, reason, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
                waived = VALUES(waived),
                override_amount = VALUES(override_amount),
                reason = VALUES(reason),
                line_type = VALUES(line_type),
                line_date = VALUES(line_date),
                line_desc = VALUES(line_desc)",
            [
                $tenantId, $employeeId, $month, $kind, $type, $date,
                $desc, $hash, $waived ? 1 : 0, $waived ? null : $amount,
                $reason, $createdBy,
            ]
        );
    }

    /** Remove an override (restores the original computed line). */
    public static function clear(
        int $tenantId,
        int $employeeId,
        string $month,
        string $kind,
        string $type,
        ?string $date,
        string $desc
    ): void {
        $hash = self::hash($type, $date, $desc);
        Database::execute(
            "DELETE FROM payroll_line_overrides
              WHERE tenant_id = ? AND employee_id = ? AND month = ?
                AND line_kind = ? AND line_hash = ?",
            [$tenantId, $employeeId, $month, $kind, $hash]
        );
    }
}
