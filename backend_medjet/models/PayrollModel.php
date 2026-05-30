<?php

final class PayrollModel {
    public static function generate(int $tenantId, string $month, ?int $branchId = null): array {
        $sql = "SELECT id FROM employees WHERE tenant_id = ? AND status = 'active'";
        $params = [$tenantId];
        if ($branchId) {
            $sql .= " AND branch_id = ?";
            $params[] = $branchId;
        }
        $employees = Database::fetchAll($sql, $params);

        $results = [];
        foreach ($employees as $emp) {
            $calculation = PayrollCalculator::calculate($emp['id'], $month, $tenantId);

            Database::execute(
                "INSERT INTO payroll (tenant_id, employee_id, branch_id, month, base_salary, total_deductions, total_bonuses, net_salary, breakdown)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                 ON DUPLICATE KEY UPDATE
                    base_salary = VALUES(base_salary),
                    total_deductions = VALUES(total_deductions),
                    total_bonuses = VALUES(total_bonuses),
                    net_salary = VALUES(net_salary),
                    breakdown = VALUES(breakdown)",
                [
                    $tenantId,
                    $emp['id'],
                    $branchId,
                    $month,
                    $calculation['base_salary'],
                    $calculation['total_deductions'],
                    $calculation['total_bonuses'],
                    $calculation['net_salary'],
                    json_encode($calculation, JSON_UNESCAPED_UNICODE),
                ]
            );

            $results[] = $calculation;
        }

        return $results;
    }

    public static function getSlip(int $employeeId, string $month, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM payroll WHERE employee_id = ? AND month = ? AND tenant_id = ? LIMIT 1",
            [$employeeId, $month, $tenantId]
        );
    }

    public static function getSlipsByMonth(int $tenantId, string $month, ?int $branchId = null, int $page = 1, int $limit = 20): array {
        $sql = "SELECT p.*, e.name as employee_name, e.job_title, b.name as branch_name
                FROM payroll p
                JOIN employees e ON e.id = p.employee_id
                LEFT JOIN branches b ON b.id = p.branch_id
                WHERE p.tenant_id = ? AND p.month = ?";
        $params = [$tenantId, $month];

        if ($branchId) {
            $sql .= " AND p.branch_id = ?";
            $params[] = $branchId;
        }

        $offset = ($page - 1) * $limit;
        $sql .= " ORDER BY e.name ASC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;

        return ['items' => Database::fetchAll($sql, $params), 'page' => $page];
    }

    /**
     * Month-to-date view for every active employee.
     * Runs PayrollCalculator on-the-fly (no DB writes) and merges
     * any saved payroll row (id / status) for the same month.
     */
    public static function getLiveOverview(int $tenantId, string $month, ?int $branchId = null, ?int $limit = null, int $offset = 0): array {
        // Aggregate category ids as a comma-separated string so the client can
        // filter without an extra round-trip per employee.
        $sql = "SELECT e.id, e.name, e.job_title, e.branch_id, e.shift_id, e.hire_date,
                       b.name AS branch_name,
                       (SELECT GROUP_CONCAT(category_id)
                          FROM employee_category_assignments
                          WHERE employee_id = e.id) AS category_ids
                FROM employees e
                LEFT JOIN branches b ON b.id = e.branch_id
                WHERE e.tenant_id = ? AND e.status = 'active' AND e.deleted_at IS NULL";
        $params = [$tenantId];
        if ($branchId !== null) {
            $sql .= " AND e.branch_id = ?";
            $params[] = $branchId;
        }
        $sql .= " ORDER BY e.name ASC";
        if ($limit !== null && $limit > 0) {
            $sql .= " LIMIT ? OFFSET ?";
            $params[] = $limit;
            $params[] = max(0, $offset);
        }
        $employees = Database::fetchAll($sql, $params);

        $savedRows = Database::fetchAll(
            "SELECT employee_id, id, status FROM payroll WHERE tenant_id = ? AND month = ?",
            [$tenantId, $month]
        );
        $savedByEmployee = [];
        foreach ($savedRows as $row) {
            $savedByEmployee[(int) $row['employee_id']] = $row;
        }

        // Previous label month's saved totals per employee — drives the
        // per-tile delta chip and the anomaly warnings. Calendar-prev is
        // also cycle-prev since we use label-month addressing throughout.
        $parts = explode('-', $month);
        $py = (int) $parts[0];
        $pm = (int) $parts[1];
        $prevMonthStr = sprintf(
            '%04d-%02d',
            $pm === 1 ? $py - 1 : $py,
            $pm === 1 ? 12 : $pm - 1
        );
        $prevByEmployee = [];
        foreach (Database::fetchAll(
            "SELECT employee_id, net_salary, total_deductions, total_bonuses
             FROM payroll WHERE tenant_id = ? AND month = ?",
            [$tenantId, $prevMonthStr]
        ) as $r) {
            $prevByEmployee[(int) $r['employee_id']] = [
                'net' => (float) $r['net_salary'],
                'deductions' => (float) $r['total_deductions'],
                'bonuses' => (float) $r['total_bonuses'],
            ];
        }

        $today = date('Y-m-d');
        $items = [];
        foreach ($employees as $emp) {
            $calc = PayrollCalculator::calculate((int) $emp['id'], $month, $tenantId, $today);
            if (empty($calc)) {
                continue;
            }
            // Skip employees who weren't hired yet by the end of this cycle —
            // they didn't exist during the period the row would represent.
            $hireDate = !empty($emp['hire_date']) ? $emp['hire_date'] : null;
            if ($hireDate !== null && $hireDate > $calc['cycle_end']) {
                continue;
            }
            $saved = $savedByEmployee[(int) $emp['id']] ?? null;
            $categoryIds = [];
            if (!empty($emp['category_ids'])) {
                foreach (explode(',', (string) $emp['category_ids']) as $cid) {
                    $cid = (int) trim($cid);
                    if ($cid > 0) $categoryIds[] = $cid;
                }
            }
            $items[] = [
                'id' => $saved ? (int) $saved['id'] : 0,
                'employee_id' => (int) $emp['id'],
                'employee_name' => $emp['name'],
                'job_title' => $emp['job_title'],
                'branch_id' => $emp['branch_id'] !== null ? (int) $emp['branch_id'] : null,
                'branch_name' => $emp['branch_name'],
                'shift_id' => $emp['shift_id'] !== null ? (int) $emp['shift_id'] : null,
                'category_ids' => $categoryIds,
                'month' => $month,
                'base_salary' => $calc['base_salary'],
                'total_deductions' => $calc['total_deductions'],
                'total_bonuses' => $calc['total_bonuses'],
                // "Net so far" for the picked cycle: base prorated by days
                // elapsed in the cycle, minus deductions, plus bonuses.
                'net_salary' => $calc['earned_to_date'],
                // Full-cycle projection (base − deductions + bonuses with full
                // base). Used by the summary card to compare apples-to-apples
                // with the previous (completed) cycle.
                'projected_net' => $calc['net_salary'],
                'prorated_base_salary' => $calc['prorated_base_salary'],
                'cycle_start' => $calc['cycle_start'],
                'cycle_end' => $calc['cycle_end'],
                'days_in_cycle' => $calc['days_in_cycle'],
                'days_elapsed' => $calc['days_elapsed'],
                'status' => $saved ? $saved['status'] : 'live',
                // Per-event breakdown so the tile can expand and show
                // *why* the totals look like they do without round-tripping
                // back to employee profile.
                'deductions_breakdown' => $calc['deductions_breakdown'] ?? [],
                'bonuses_breakdown' => $calc['bonuses_breakdown'] ?? [],
                // Per-employee previous-cycle snapshot (null when nothing
                // was generated for that employee in the prior month).
                'previous_net' => isset($prevByEmployee[(int) $emp['id']])
                    ? $prevByEmployee[(int) $emp['id']]['net']
                    : null,
                'previous_deductions' => isset($prevByEmployee[(int) $emp['id']])
                    ? $prevByEmployee[(int) $emp['id']]['deductions']
                    : null,
                'previous_bonuses' => isset($prevByEmployee[(int) $emp['id']])
                    ? $prevByEmployee[(int) $emp['id']]['bonuses']
                    : null,
            ];
        }

        // Total count of active (filterable) employees so the client can
        // tell whether more pages exist.
        $countSql = "SELECT COUNT(*) AS c FROM employees e
                     WHERE e.tenant_id = ? AND e.status = 'active' AND e.deleted_at IS NULL";
        $countParams = [$tenantId];
        if ($branchId !== null) {
            $countSql .= " AND e.branch_id = ?";
            $countParams[] = $branchId;
        }
        $totalRow = Database::fetchOne($countSql, $countParams);
        return [
            'items' => $items,
            'total_count' => (int) ($totalRow['c'] ?? count($items)),
        ];
    }

    public static function approve(int $payrollId, int $tenantId, int $approvedBy): void {
        Database::execute(
            "UPDATE payroll SET status = 'approved', approved_by = ?, approved_at = NOW() WHERE id = ? AND tenant_id = ?",
            [$approvedBy, $payrollId, $tenantId]
        );
    }

    /**
     * Steps a slip one state back: paid → approved, or approved → draft. Used
     * by the financial tab's "Revert" action so corrections can be made
     * without deleting the row. Returns the prior status on success, null when
     * the slip is not found or already at draft.
     */
    public static function revert(int $payrollId, int $tenantId): ?string {
        $slip = Database::fetchOne(
            "SELECT status FROM payroll WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$payrollId, $tenantId]
        );
        if (!$slip) return null;
        $from = $slip['status'];
        if ($from === 'paid') {
            Database::execute(
                "UPDATE payroll SET status = 'approved', paid_at = NULL
                 WHERE id = ? AND tenant_id = ?",
                [$payrollId, $tenantId]
            );
            return 'paid';
        }
        if ($from === 'approved') {
            Database::execute(
                "UPDATE payroll SET status = 'draft', approved_by = NULL, approved_at = NULL
                 WHERE id = ? AND tenant_id = ?",
                [$payrollId, $tenantId]
            );
            return 'approved';
        }
        return null;
    }

    /**
     * Mark a draft slip as approved. Returns the (employee_id, month) pairs
     * that were actually flipped so the caller can settle loans, dispatch
     * alerts, etc. Skips ids that are not in 'draft' state for the tenant.
     */
    public static function approveMany(array $ids, int $tenantId, int $approvedBy): array {
        $ids = array_values(array_filter(array_map('intval', $ids), fn($x) => $x > 0));
        if (empty($ids)) return [];

        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $touched = Database::fetchAll(
            "SELECT id, employee_id, month FROM payroll
             WHERE id IN ($placeholders) AND tenant_id = ? AND status = 'draft'",
            array_merge($ids, [$tenantId])
        );
        if (empty($touched)) return [];

        $touchedIds = array_map(fn($r) => (int) $r['id'], $touched);
        $tp = implode(',', array_fill(0, count($touchedIds), '?'));
        Database::execute(
            "UPDATE payroll SET status = 'approved', approved_by = ?, approved_at = NOW()
             WHERE id IN ($tp) AND tenant_id = ?",
            array_merge([$approvedBy], $touchedIds, [$tenantId])
        );

        return $touched;
    }

    /**
     * Move approved slips into the 'paid' state. `paidAt` is "YYYY-MM-DD";
     * NULL leaves the timestamp default (CURRENT_TIMESTAMP). Only slips in
     * 'approved' state are touched, so callers can pass mixed selections
     * without worrying about state machine violations.
     */
    public static function markPaidMany(array $ids, int $tenantId, ?string $paidAt = null): array {
        $ids = array_values(array_filter(array_map('intval', $ids), fn($x) => $x > 0));
        if (empty($ids)) return [];

        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $touched = Database::fetchAll(
            "SELECT id, employee_id, month FROM payroll
             WHERE id IN ($placeholders) AND tenant_id = ? AND status = 'approved'",
            array_merge($ids, [$tenantId])
        );
        if (empty($touched)) return [];

        $touchedIds = array_map(fn($r) => (int) $r['id'], $touched);
        $tp = implode(',', array_fill(0, count($touchedIds), '?'));

        if ($paidAt !== null) {
            Database::execute(
                "UPDATE payroll SET status = 'paid', paid_at = ?
                 WHERE id IN ($tp) AND tenant_id = ?",
                array_merge([$paidAt], $touchedIds, [$tenantId])
            );
        } else {
            Database::execute(
                "UPDATE payroll SET status = 'paid', paid_at = NOW()
                 WHERE id IN ($tp) AND tenant_id = ?",
                array_merge($touchedIds, [$tenantId])
            );
        }

        return $touched;
    }

    public static function getTotalByMonth(int $tenantId, string $month, ?int $branchId = null): array {
        $sql = "SELECT
                    COUNT(*) as employee_count,
                    SUM(base_salary) as total_base,
                    SUM(total_deductions) as total_deductions,
                    SUM(total_bonuses) as total_bonuses,
                    SUM(net_salary) as total_net
                FROM payroll WHERE tenant_id = ? AND month = ?";
        $params = [$tenantId, $month];

        if ($branchId) {
            $sql .= " AND branch_id = ?";
            $params[] = $branchId;
        }

        return Database::fetchOne($sql, $params) ?: [];
    }

    public static function getReportByMonth(
        int $tenantId,
        string $month,
        ?int $branchId = null
    ): array {
        $sql = "SELECT
                    p.id,
                    p.employee_id,
                    e.name as employee_name,
                    e.job_title,
                    b.name as branch_name,
                    p.base_salary,
                    p.total_deductions,
                    p.total_bonuses,
                    p.overtime_total_minutes,
                    p.net_salary,
                    p.status
                FROM payroll p
                JOIN employees e ON e.id = p.employee_id
                LEFT JOIN branches b ON b.id = p.branch_id
                WHERE p.tenant_id = ? AND p.month = ?";
        $params = [$tenantId, $month];
        if ($branchId !== null) {
            $sql .= " AND p.branch_id = ?";
            $params[] = $branchId;
        }
        $sql .= " ORDER BY e.name ASC";
        return Database::fetchAll($sql, $params);
    }

    public static function getReportSummary(
        int $tenantId,
        string $month,
        ?int $branchId = null
    ): array {
        $sql = "SELECT
                    COUNT(*) as employee_count,
                    COUNT(CASE WHEN status = 'draft' THEN 1 END) as draft_count,
                    COUNT(CASE WHEN status = 'approved' THEN 1 END) as approved_count,
                    COUNT(CASE WHEN status = 'paid' THEN 1 END) as paid_count,
                    COALESCE(SUM(base_salary), 0) as total_base,
                    COALESCE(SUM(total_deductions), 0) as total_deductions,
                    COALESCE(SUM(total_bonuses), 0) as total_bonuses,
                    COALESCE(SUM(overtime_total_minutes), 0) as total_overtime_minutes,
                    COALESCE(SUM(net_salary), 0) as total_net
                FROM payroll
                WHERE tenant_id = ? AND month = ?";
        $params = [$tenantId, $month];
        if ($branchId !== null) {
            $sql .= " AND branch_id = ?";
            $params[] = $branchId;
        }
        return Database::fetchOne($sql, $params) ?: [];
    }

    public static function getApprovedForBankFile(int $tenantId, string $month, ?int $branchId = null): array {
        $sql = "SELECT e.name AS employee_name, e.id AS employee_id,
                       e.bank_name, e.bank_account_number, e.bank_iban,
                       p.net_salary, p.branch_id,
                       b.name AS branch_name
                FROM payroll p
                JOIN employees e ON e.id = p.employee_id
                LEFT JOIN branches b ON b.id = p.branch_id
                WHERE p.tenant_id = ? AND p.month = ? AND p.status = 'approved'";
        $params = [$tenantId, $month];
        if ($branchId) {
            $sql .= " AND p.branch_id = ?";
            $params[] = $branchId;
        }
        $sql .= " ORDER BY e.name ASC";
        return Database::fetchAll($sql, $params);
    }
}
