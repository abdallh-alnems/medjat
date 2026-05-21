<?php

final class ExpenseModel {
    public const CATEGORIES = ['travel', 'meals', 'accommodation', 'supplies', 'medical', 'communication', 'other'];
    public const STATUSES = ['pending', 'approved', 'rejected', 'reimbursed'];

    public static function create(
        int $tenantId,
        int $employeeId,
        string $category,
        float $amount,
        string $expenseDate,
        ?string $description,
        ?string $currency,
        ?string $receiptUrl,
        int $createdBy
    ): int {
        Database::execute(
            "INSERT INTO expense_claims
                (tenant_id, employee_id, category, amount, currency, description, expense_date, receipt_url, status, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)",
            [
                $tenantId, $employeeId, $category, $amount,
                $currency ?: 'SAR', $description, $expenseDate, $receiptUrl, $createdBy,
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM expense_claims WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        );
    }

    public static function listByTenant(int $tenantId, ?string $status = null, ?int $employeeId = null): array {
        $sql = "SELECT ec.*, e.name AS employee_name
                FROM expense_claims ec
                JOIN employees e ON e.id = ec.employee_id
                WHERE ec.tenant_id = ?";
        $params = [$tenantId];
        if ($status !== null && $status !== '') {
            $sql .= " AND ec.status = ?";
            $params[] = $status;
        }
        if ($employeeId !== null) {
            $sql .= " AND ec.employee_id = ?";
            $params[] = $employeeId;
        }
        $sql .= " ORDER BY ec.created_at DESC";
        return Database::fetchAll($sql, $params);
    }

    public static function approve(int $id, int $tenantId, int $adminId): void {
        Database::execute(
            "UPDATE expense_claims
             SET status = 'approved', reviewed_by = ?, reviewed_at = NOW(), rejection_reason = NULL
             WHERE id = ? AND tenant_id = ? AND status = 'pending'",
            [$adminId, $id, $tenantId]
        );
    }

    public static function reject(int $id, int $tenantId, int $adminId, ?string $reason): void {
        Database::execute(
            "UPDATE expense_claims
             SET status = 'rejected', reviewed_by = ?, reviewed_at = NOW(), rejection_reason = ?
             WHERE id = ? AND tenant_id = ? AND status = 'pending'",
            [$adminId, $reason, $id, $tenantId]
        );
    }

    public static function markReimbursed(int $id, int $tenantId, int $adminId): void {
        Database::execute(
            "UPDATE expense_claims
             SET status = 'reimbursed', reviewed_by = ?, reviewed_at = NOW()
             WHERE id = ? AND tenant_id = ? AND status = 'approved'",
            [$adminId, $id, $tenantId]
        );
    }
}
