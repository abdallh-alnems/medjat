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

    public static function approve(int $payrollId, int $tenantId, int $approvedBy): void {
        Database::execute(
            "UPDATE payroll SET status = 'approved', approved_by = ?, approved_at = NOW() WHERE id = ? AND tenant_id = ?",
            [$approvedBy, $payrollId, $tenantId]
        );
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
}
