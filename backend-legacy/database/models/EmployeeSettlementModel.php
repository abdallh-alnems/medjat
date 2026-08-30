<?php

/**
 * End-of-service / Full & Final Settlement records ("تسوية نهاية الخدمة").
 *
 * One settlement per employee (unique on tenant+employee). Created as a draft,
 * editable until approved; approving freezes the figures and terminates the
 * employee. See migrations/2026_06_09_employee_settlements.sql for the column
 * semantics. SettlementCalculator computes the suggested figures; this model is
 * only persistence.
 */
final class EmployeeSettlementModel {
    public const REASONS = [
        'resignation', 'termination', 'end_of_contract',
        'retirement', 'death', 'absconding', 'other',
    ];

    /** Editable money fields HR can override before approval. */
    private const MONEY_FIELDS = [
        'pending_salary', 'gratuity_days', 'gratuity_amount',
        'leave_balance_days', 'leave_encashment', 'other_additions',
        'outstanding_loans', 'other_deductions',
    ];

    /** The saved settlement for an employee, or null. */
    public static function getForEmployee(int $employeeId, int $tenantId): ?array {
        $row = Database::fetchOne(
            "SELECT s.*, c.name AS created_by_name, a.name AS approved_by_name
             FROM employee_settlements s
             LEFT JOIN admins c ON c.id = s.created_by
             LEFT JOIN admins a ON a.id = s.approved_by
             WHERE s.employee_id = ? AND s.tenant_id = ? LIMIT 1",
            [$employeeId, $tenantId]
        );
        return self::decode($row);
    }

    /**
     * Remove an employee's settlement entirely. Used when re-hiring a
     * terminated employee so a future end-of-service starts from a clean draft
     * instead of being blocked by the previous (approved/paid) record.
     */
    public static function deleteForEmployee(int $employeeId, int $tenantId): bool {
        return Database::execute(
            "DELETE FROM employee_settlements WHERE employee_id = ? AND tenant_id = ?",
            [$employeeId, $tenantId]
        ) >= 0;
    }

    public static function findById(int $id, int $tenantId): ?array {
        $row = Database::fetchOne(
            "SELECT * FROM employee_settlements WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
        return self::decode($row);
    }

    /** JSON-decode the line_items/breakdown columns of a fetched row. */
    private static function decode(?array $row): ?array {
        if (!$row) {
            return null;
        }
        $row['line_items'] = $row['line_items'] ? json_decode($row['line_items'], true) : [];
        $row['breakdown'] = $row['breakdown'] ? json_decode($row['breakdown'], true) : null;
        return $row;
    }

    /**
     * Insert or update the draft settlement for an employee. Recomputes the
     * three totals from the supplied figures + custom line items so the stored
     * row is always internally consistent. Returns the settlement id.
     */
    public static function upsert(int $tenantId, int $employeeId, array $data, ?int $adminId): int {
        $lineItems = self::sanitizeLineItems($data['line_items'] ?? []);
        [$totalEarnings, $totalDeductions, $netAmount] = self::totals($data, $lineItems);

        $existing = Database::fetchOne(
            "SELECT id, status FROM employee_settlements
             WHERE employee_id = ? AND tenant_id = ? LIMIT 1",
            [$employeeId, $tenantId]
        );

        $params = [
            'reason'             => in_array($data['reason'] ?? '', self::REASONS, true) ? $data['reason'] : 'resignation',
            'notes'              => $data['notes'] ?? null,
            'last_working_day'   => $data['last_working_day'],
            'hire_date'          => $data['hire_date'] ?? null,
            'base_salary'        => (float) ($data['base_salary'] ?? 0),
            'daily_rate'         => (float) ($data['daily_rate'] ?? 0),
            'years_of_service'   => (float) ($data['years_of_service'] ?? 0),
            'pending_salary'     => (float) ($data['pending_salary'] ?? 0),
            'gratuity_days'      => (float) ($data['gratuity_days'] ?? 0),
            'gratuity_amount'    => (float) ($data['gratuity_amount'] ?? 0),
            'leave_balance_days' => (float) ($data['leave_balance_days'] ?? 0),
            'leave_encashment'   => (float) ($data['leave_encashment'] ?? 0),
            'other_additions'    => (float) ($data['other_additions'] ?? 0),
            'outstanding_loans'  => (float) ($data['outstanding_loans'] ?? 0),
            'other_deductions'   => (float) ($data['other_deductions'] ?? 0),
            'total_earnings'     => $totalEarnings,
            'total_deductions'   => $totalDeductions,
            'net_amount'         => $netAmount,
            'line_items'         => json_encode($lineItems, JSON_UNESCAPED_UNICODE),
        ];

        if ($existing) {
            $sets = [];
            $vals = [];
            foreach ($params as $col => $val) {
                $sets[] = "`$col` = ?";
                $vals[] = $val;
            }
            $vals[] = (int) $existing['id'];
            $vals[] = $tenantId;
            Database::execute(
                "UPDATE employee_settlements SET " . implode(', ', $sets) .
                " WHERE id = ? AND tenant_id = ?",
                $vals
            );
            return (int) $existing['id'];
        }

        $cols = array_keys($params);
        $cols[] = 'tenant_id';
        $cols[] = 'employee_id';
        $cols[] = 'created_by';
        $placeholders = implode(', ', array_fill(0, count($cols), '?'));
        $vals = array_values($params);
        $vals[] = $tenantId;
        $vals[] = $employeeId;
        $vals[] = $adminId;

        Database::execute(
            "INSERT INTO employee_settlements (`" . implode('`, `', $cols) . "`) VALUES ($placeholders)",
            $vals
        );
        return (int) Database::lastInsertId();
    }

    /**
     * Approve a draft: freeze the computed snapshot and stamp the approver.
     * Caller terminates the employee row.
     */
    public static function approve(int $id, int $tenantId, ?int $adminId, array $snapshot): bool {
        return Database::execute(
            "UPDATE employee_settlements
             SET status = 'approved', approved_by = ?, approved_at = NOW(),
                 breakdown = ?
             WHERE id = ? AND tenant_id = ? AND status = 'draft'",
            [$adminId, json_encode($snapshot, JSON_UNESCAPED_UNICODE), $id, $tenantId]
        ) > 0;
    }

    public static function markPaid(int $id, int $tenantId): bool {
        return Database::execute(
            "UPDATE employee_settlements
             SET status = 'paid', paid_at = NOW()
             WHERE id = ? AND tenant_id = ? AND status = 'approved'",
            [$id, $tenantId]
        ) > 0;
    }

    /** Recompute (total_earnings, total_deductions, net_amount). */
    public static function totals(array $data, array $lineItems): array {
        $earnings = (float) ($data['pending_salary'] ?? 0)
            + (float) ($data['gratuity_amount'] ?? 0)
            + (float) ($data['leave_encashment'] ?? 0)
            + (float) ($data['other_additions'] ?? 0);
        $deductions = (float) ($data['outstanding_loans'] ?? 0)
            + (float) ($data['other_deductions'] ?? 0);

        foreach ($lineItems as $item) {
            $amount = (float) ($item['amount'] ?? 0);
            if (($item['kind'] ?? 'earning') === 'deduction') {
                $deductions += $amount;
            } else {
                $earnings += $amount;
            }
        }

        return [
            round($earnings, 2),
            round($deductions, 2),
            round($earnings - $deductions, 2),
        ];
    }

    /** Keep only well-formed custom rows: {label, kind, amount}. */
    private static function sanitizeLineItems($raw): array {
        if (!is_array($raw)) {
            return [];
        }
        $clean = [];
        foreach ($raw as $item) {
            if (!is_array($item)) {
                continue;
            }
            $label = trim((string) ($item['label'] ?? ''));
            if ($label === '') {
                continue;
            }
            $kind = ($item['kind'] ?? 'earning') === 'deduction' ? 'deduction' : 'earning';
            $clean[] = [
                'label'  => $label,
                'kind'   => $kind,
                'amount' => round((float) ($item['amount'] ?? 0), 2),
            ];
        }
        return $clean;
    }
}
