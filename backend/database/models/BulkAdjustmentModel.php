<?php

/**
 * A bulk bonus/deduction "batch": one admin action that fans out into many
 * per-employee manual_bonuses / manual_deductions rows (each tagged with the
 * batch id). The child rows are what payroll actually reads; this table only
 * tracks the batch so it can be listed, edited (recomputed) or removed later.
 */
final class BulkAdjustmentModel {
    /** Map a batch kind to the per-employee table it fans out into. */
    private static function childTable(string $kind): string {
        return $kind === 'bonus' ? 'manual_bonuses' : 'manual_deductions';
    }

    public static function create(
        int $tenantId,
        string $kind,
        string $scopeType,
        ?int $scopeId,
        ?string $scopeName,
        float $amount,
        string $amountType,
        string $reason,
        int $createdBy,
        ?string $month = null
    ): int {
        $month = $month ?: date('Y-m');
        Database::execute(
            "INSERT INTO bulk_adjustments
                (tenant_id, kind, scope_type, scope_id, scope_name, amount, amount_type, reason, month, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [$tenantId, $kind, $scopeType, $scopeId, $scopeName, $amount, $amountType, $reason, $month, $createdBy]
        );
        return (int) Database::lastInsertId();
    }

    /**
     * Whether a batch with the same kind + scope + month already exists for the
     * tenant — used to warn the admin before applying a likely duplicate.
     * scope_id is NULL-safe (the 'all' scope).
     */
    public static function existsSimilar(
        int $tenantId,
        string $kind,
        string $scopeType,
        ?int $scopeId,
        string $month
    ): bool {
        $row = Database::fetchOne(
            "SELECT id FROM bulk_adjustments
             WHERE tenant_id = ? AND kind = ? AND scope_type = ? AND month = ?
               AND ((scope_id IS NULL AND ? IS NULL) OR scope_id = ?)
             LIMIT 1",
            [$tenantId, $kind, $scopeType, $month, $scopeId, $scopeId]
        );
        return $row !== null;
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM bulk_adjustments WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    /** Batches for a tenant, newest first, with member count + total figure. */
    public static function listByTenant(int $tenantId): array {
        return Database::fetchAll(
            "SELECT ba.*, a.name AS created_by_name,
                CASE ba.kind
                    WHEN 'bonus' THEN (SELECT COUNT(*) FROM manual_bonuses WHERE batch_id = ba.id)
                    ELSE (SELECT COUNT(*) FROM manual_deductions WHERE batch_id = ba.id)
                END AS member_count,
                CASE ba.kind
                    WHEN 'bonus' THEN (SELECT COALESCE(SUM(amount), 0) FROM manual_bonuses WHERE batch_id = ba.id)
                    ELSE (SELECT COALESCE(SUM(amount), 0) FROM manual_deductions WHERE batch_id = ba.id)
                END AS total_amount
             FROM bulk_adjustments ba
             LEFT JOIN admins a ON a.id = ba.created_by
             WHERE ba.tenant_id = ?
             ORDER BY ba.created_at DESC",
            [$tenantId]
        );
    }

    /**
     * The per-employee rows of a batch, with each employee's name, base salary
     * and linked account id (for notifications). Returns id (the child row id),
     * employee_id, amount, reason.
     */
    public static function getMembers(int $batchId, string $kind, int $tenantId): array {
        $table = self::childTable($kind);
        return Database::fetchAll(
            "SELECT m.id, m.employee_id, m.amount, m.reason,
                    e.name AS employee_name, e.base_salary, e.admin_id
             FROM {$table} m
             JOIN employees e ON e.id = m.employee_id
             WHERE m.batch_id = ? AND m.tenant_id = ?
             ORDER BY e.name ASC",
            [$batchId, $tenantId]
        );
    }

    public static function findMember(int $rowId, int $batchId, string $kind, int $tenantId): ?array {
        $table = self::childTable($kind);
        return Database::fetchOne(
            "SELECT m.id, m.employee_id, m.amount, e.admin_id
             FROM {$table} m
             JOIN employees e ON e.id = m.employee_id
             WHERE m.id = ? AND m.batch_id = ? AND m.tenant_id = ? LIMIT 1",
            [$rowId, $batchId, $tenantId]
        );
    }

    public static function updateMemberAmount(int $rowId, string $kind, int $tenantId, float $amount, string $reason): bool {
        $table = self::childTable($kind);
        return Database::execute(
            "UPDATE {$table} SET amount = ?, reason = ? WHERE id = ? AND tenant_id = ?",
            [$amount, $reason, $rowId, $tenantId]
        ) > 0;
    }

    public static function removeMember(int $rowId, int $batchId, string $kind, int $tenantId): bool {
        $table = self::childTable($kind);
        return Database::execute(
            "DELETE FROM {$table} WHERE id = ? AND batch_id = ? AND tenant_id = ?",
            [$rowId, $batchId, $tenantId]
        ) > 0;
    }

    public static function updateMeta(int $id, int $tenantId, float $amount, string $amountType, string $reason): bool {
        return Database::execute(
            "UPDATE bulk_adjustments SET amount = ?, amount_type = ?, reason = ? WHERE id = ? AND tenant_id = ?",
            [$amount, $amountType, $reason, $id, $tenantId]
        ) > 0;
    }

    /** Delete the batch and every per-employee row it created. */
    public static function deleteBatch(int $id, string $kind, int $tenantId): void {
        $table = self::childTable($kind);
        $con = Database::getInstance();
        $con->beginTransaction();
        try {
            Database::execute("DELETE FROM {$table} WHERE batch_id = ? AND tenant_id = ?", [$id, $tenantId]);
            Database::execute("DELETE FROM bulk_adjustments WHERE id = ? AND tenant_id = ?", [$id, $tenantId]);
            $con->commit();
        } catch (Exception $e) {
            $con->rollBack();
            throw $e;
        }
    }
}
