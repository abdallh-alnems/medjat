<?php

final class LoanModel {
    public const TYPES = ['loan', 'advance'];
    public const STATUSES = ['pending', 'active', 'completed', 'cancelled', 'rejected'];

    public static function countPending(int $tenantId): int {
        return (int) (Database::fetchOne(
            "SELECT COUNT(*) AS c FROM employee_loans WHERE tenant_id = ? AND status = 'pending'",
            [$tenantId]
        )['c'] ?? 0);
    }

    /** Pending advance/loan requests an employee already has awaiting a decision. */
    public static function countPendingForEmployee(int $employeeId, int $tenantId): int {
        return (int) (Database::fetchOne(
            "SELECT COUNT(*) AS c FROM employee_loans
             WHERE employee_id = ? AND tenant_id = ? AND status = 'pending'",
            [$employeeId, $tenantId]
        )['c'] ?? 0);
    }

    public static function create(
        int $tenantId,
        int $employeeId,
        string $type,
        float $totalAmount,
        float $installmentAmount,
        int $installmentsCount,
        string $startMonth,
        ?string $reason,
        ?int $createdBy
    ): int {
        Database::execute(
            "INSERT INTO employee_loans
                (tenant_id, employee_id, type, total_amount, installment_amount, installments_count, start_month, reason, status, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)",
            [
                $tenantId, $employeeId, $type, $totalAmount,
                $installmentAmount, $installmentsCount, $startMonth, $reason, $createdBy,
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT el.*, e.name AS employee_name
             FROM employee_loans el
             JOIN employees e ON e.id = el.employee_id
             WHERE el.id = ? AND el.tenant_id = ?",
            [$id, $tenantId]
        );
    }

    public static function listByTenant(int $tenantId, ?string $status = null, ?int $employeeId = null): array {
        $sql = "SELECT el.*, e.name AS employee_name
                FROM employee_loans el
                JOIN employees e ON e.id = el.employee_id
                WHERE el.tenant_id = ?";
        $params = [$tenantId];
        if ($status !== null && $status !== '') {
            $sql .= " AND el.status = ?";
            $params[] = $status;
        }
        if ($employeeId !== null) {
            $sql .= " AND el.employee_id = ?";
            $params[] = $employeeId;
        }
        $sql .= " ORDER BY el.created_at DESC";
        return Database::fetchAll($sql, $params);
    }

    public static function getInstallments(int $loanId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM loan_installments WHERE loan_id = ? AND tenant_id = ? ORDER BY seq ASC",
            [$loanId, $tenantId]
        );
    }

    /**
     * Active and pending loans/advances for one employee, each enriched with
     * paid / remaining totals and the next due installment. Used by the
     * financial tab's loans card so the employee/admin sees outstanding
     * balances without an extra round-trip.
     */
    public static function getActiveSummaryForEmployee(int $employeeId, int $tenantId): array {
        $loans = Database::fetchAll(
            "SELECT id, type, total_amount, installment_amount, installments_count,
                    installments_paid, start_month, reason, status, created_at, approved_at
             FROM employee_loans
             WHERE employee_id = ? AND tenant_id = ?
               AND status IN ('pending','active')
             ORDER BY created_at DESC",
            [$employeeId, $tenantId]
        );
        foreach ($loans as &$loan) {
            $sums = Database::fetchOne(
                "SELECT
                    COALESCE(SUM(CASE WHEN status='paid' THEN amount ELSE 0 END), 0)    AS paid_amount,
                    COALESCE(SUM(CASE WHEN status='pending' THEN amount ELSE 0 END), 0) AS remaining_amount,
                    MIN(CASE WHEN status='pending' THEN month END)                       AS next_due_month,
                    COUNT(CASE WHEN status='pending' THEN 1 END)                         AS remaining_installments
                 FROM loan_installments
                 WHERE loan_id = ? AND tenant_id = ?",
                [(int) $loan['id'], $tenantId]
            );
            $loan['paid_amount']            = (float) ($sums['paid_amount'] ?? 0);
            $loan['remaining_amount']       = (float) ($sums['remaining_amount'] ?? 0);
            $loan['next_due_month']         = $sums['next_due_month'] ?? null;
            $loan['remaining_installments'] = (int) ($sums['remaining_installments'] ?? 0);
        }
        unset($loan);
        return $loans;
    }

    /**
     * Approve a pending loan: activate it and generate the monthly installment
     * schedule starting from start_month. The final installment absorbs any
     * rounding remainder so the schedule sums exactly to total_amount.
     */
    public static function approve(int $loanId, int $tenantId, int $adminId): bool {
        $loan = self::findById($loanId, $tenantId);
        if (!$loan || $loan['status'] !== 'pending') {
            return false;
        }

        $count = max(1, (int) $loan['installments_count']);
        $total = round((float) $loan['total_amount'], 2);
        $perInstallment = round((float) $loan['installment_amount'], 2);

        $con = Database::getInstance();
        $con->beginTransaction();
        try {
            Database::execute(
                "UPDATE employee_loans
                 SET status = 'active', approved_by = ?, approved_at = NOW()
                 WHERE id = ? AND tenant_id = ?",
                [$adminId, $loanId, $tenantId]
            );

            $month = self::parseMonth($loan['start_month']);
            $accumulated = 0.0;
            for ($i = 1; $i <= $count; $i++) {
                $amount = ($i === $count) ? round($total - $accumulated, 2) : $perInstallment;
                $accumulated = round($accumulated + $amount, 2);
                Database::execute(
                    "INSERT INTO loan_installments (tenant_id, loan_id, employee_id, month, seq, amount, status)
                     VALUES (?, ?, ?, ?, ?, ?, 'pending')",
                    [
                        $tenantId, $loanId, (int) $loan['employee_id'],
                        $month->format('Y-m'), $i, $amount,
                    ]
                );
                $month->modify('+1 month');
            }
            $con->commit();
            return true;
        } catch (Exception $e) {
            $con->rollBack();
            throw $e;
        }
    }

    /**
     * Reject a still-pending request. Distinct from cancel() so the employee's
     * history shows a rejection rather than a withdrawal. No installments exist
     * yet (they're only generated on approval), so nothing to clean up.
     */
    public static function reject(int $loanId, int $tenantId): bool {
        $loan = self::findById($loanId, $tenantId);
        if (!$loan || $loan['status'] !== 'pending') {
            return false;
        }
        Database::execute(
            "UPDATE employee_loans SET status = 'rejected' WHERE id = ? AND tenant_id = ?",
            [$loanId, $tenantId]
        );
        return true;
    }

    public static function cancel(int $loanId, int $tenantId): bool {
        $loan = self::findById($loanId, $tenantId);
        if (!$loan || in_array($loan['status'], ['completed', 'cancelled'], true)) {
            return false;
        }
        $con = Database::getInstance();
        $con->beginTransaction();
        try {
            Database::execute(
                "UPDATE employee_loans SET status = 'cancelled' WHERE id = ? AND tenant_id = ?",
                [$loanId, $tenantId]
            );
            // Drop any not-yet-paid installments so they stop hitting payroll.
            Database::execute(
                "DELETE FROM loan_installments WHERE loan_id = ? AND tenant_id = ? AND status = 'pending'",
                [$loanId, $tenantId]
            );
            $con->commit();
            return true;
        } catch (Exception $e) {
            $con->rollBack();
            throw $e;
        }
    }

    /** Pending installments due for an employee in a given month (used by payroll). */
    public static function dueInstallmentsForMonth(int $employeeId, string $month, int $tenantId): array {
        return Database::fetchAll(
            "SELECT li.*, el.type AS loan_type
             FROM loan_installments li
             JOIN employee_loans el ON el.id = li.loan_id
             WHERE li.employee_id = ? AND li.month = ? AND li.tenant_id = ?
               AND li.status = 'pending' AND el.status = 'active'",
            [$employeeId, $month, $tenantId]
        );
    }

    /**
     * Mark this month's pending installments as paid for an employee and advance
     * each loan's progress, completing loans whose installments are all paid.
     * Called when a payroll slip is approved.
     */
    public static function settleMonth(int $employeeId, string $month, int $tenantId): void {
        $due = self::dueInstallmentsForMonth($employeeId, $month, $tenantId);
        if (!$due) {
            return;
        }
        $con = Database::getInstance();
        $con->beginTransaction();
        try {
            foreach ($due as $inst) {
                Database::execute(
                    "UPDATE loan_installments SET status = 'paid', paid_at = NOW()
                     WHERE id = ? AND tenant_id = ?",
                    [(int) $inst['id'], $tenantId]
                );
                Database::execute(
                    "UPDATE employee_loans SET installments_paid = installments_paid + 1
                     WHERE id = ? AND tenant_id = ?",
                    [(int) $inst['loan_id'], $tenantId]
                );
                Database::execute(
                    "UPDATE employee_loans SET status = 'completed'
                     WHERE id = ? AND tenant_id = ? AND installments_paid >= installments_count AND status = 'active'",
                    [(int) $inst['loan_id'], $tenantId]
                );
            }
            $con->commit();
        } catch (Exception $e) {
            $con->rollBack();
            throw $e;
        }
    }

    private static function parseMonth(string $month): DateTime {
        $dt = DateTime::createFromFormat('Y-m-d', $month . '-01');
        return $dt instanceof DateTime ? $dt : new DateTime('first day of this month');
    }
}
