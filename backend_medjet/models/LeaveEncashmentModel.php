<?php

/**
 * Leave encashment (cash payout) records. Created at year-end rollover when a
 * carryover policy says excess days (above the cap) — or the statutory minimum
 * when carryover is disabled — should be paid out instead of forfeited. Each
 * pending record is surfaced in payroll as a "leave_encashment" bonus line and
 * flipped to `paid` once that month's payroll is approved.
 *
 * @see LeaveModel::rolloverYear() which creates the records
 * @see PayrollCalculator::calculateBonuses() which pays them out
 * @see PayrollModel::approve()/approveMany() which marks them paid
 */
final class LeaveEncashmentModel {

    /**
     * Record (or refresh) a pending encashment for one employee/source year.
     * Idempotent: re-running rollover updates the figures rather than duplicating.
     * A paid record is never overwritten.
     */
    public static function create(
        int $tenantId,
        int $employeeId,
        int $sourceYear,
        int $days,
        float $dailyRate
    ): void {
        $amount = round($days * $dailyRate, 2);
        Database::execute(
            "INSERT INTO leave_encashments
                (tenant_id, employee_id, source_year, days, daily_rate, amount, status)
             VALUES (?, ?, ?, ?, ?, ?, 'pending')
             ON DUPLICATE KEY UPDATE
                days = IF(status = 'paid', days, VALUES(days)),
                daily_rate = IF(status = 'paid', daily_rate, VALUES(daily_rate)),
                amount = IF(status = 'paid', amount, VALUES(amount))",
            [$tenantId, $employeeId, $sourceYear, $days, $dailyRate, $amount]
        );
    }

    /**
     * Pending encashments for an employee that should be paid in $month.
     * (All pending rows are due; $month is recorded when they are paid.)
     *
     * @return array<int,array{id:int,source_year:int,days:int,amount:float}>
     */
    public static function getPendingForMonth(int $employeeId, string $month, int $tenantId): array {
        $rows = Database::fetchAll(
            "SELECT id, source_year, days, amount
               FROM leave_encashments
              WHERE employee_id = ? AND tenant_id = ? AND status = 'pending'
              ORDER BY source_year",
            [$employeeId, $tenantId]
        );
        return array_map(static fn($r) => [
            'id' => (int) $r['id'],
            'source_year' => (int) $r['source_year'],
            'days' => (int) $r['days'],
            'amount' => (float) $r['amount'],
        ], $rows);
    }

    /** Flip all currently-pending encashments for these employees to paid for $month. */
    public static function markPaidForEmployees(array $employeeIds, string $month, int $tenantId): void {
        $employeeIds = array_values(array_unique(array_map('intval', $employeeIds)));
        if (empty($employeeIds)) {
            return;
        }
        $placeholders = implode(',', array_fill(0, count($employeeIds), '?'));
        Database::execute(
            "UPDATE leave_encashments
                SET status = 'paid', payroll_month = ?
              WHERE tenant_id = ? AND status = 'pending' AND employee_id IN ($placeholders)",
            array_merge([$month, $tenantId], $employeeIds)
        );
    }

    /** All encashment records for the management UI, newest first. */
    public static function listForTenant(int $tenantId, ?string $status = null, int $limit = 200): array {
        $sql = "SELECT le.id, le.employee_id, e.name AS employee_name, le.source_year,
                       le.days, le.daily_rate, le.amount, le.status, le.payroll_month, le.created_at
                  FROM leave_encashments le
                  JOIN employees e ON e.id = le.employee_id
                 WHERE le.tenant_id = ?";
        $params = [$tenantId];
        if ($status !== null && $status !== '') {
            $sql .= " AND le.status = ?";
            $params[] = $status;
        }
        $sql .= " ORDER BY le.created_at DESC LIMIT " . max(1, min(1000, $limit));
        return Database::fetchAll($sql, $params);
    }
}
