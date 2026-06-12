<?php

final class DeductionRuleModel {
    public static function getActiveByTenant(int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM deduction_rules WHERE tenant_id = ? AND is_active = 1 ORDER BY rule_key ASC",
            [$tenantId]
        );
    }

    public static function upsert(int $tenantId, string $ruleKey, string $ruleType, $ruleValue, ?string $description = null): void {
        Database::execute(
            "INSERT INTO deduction_rules (tenant_id, rule_key, rule_type, rule_value, description, is_active)
             VALUES (?, ?, ?, ?, ?, 1)
             ON DUPLICATE KEY UPDATE rule_type = VALUES(rule_type), rule_value = VALUES(rule_value), description = VALUES(description)",
            [$tenantId, $ruleKey, $ruleType, $ruleValue, $description]
        );
    }

    public static function addManualDeduction(int $employeeId, int $tenantId, float $amount, string $reason, int $createdBy, ?int $batchId = null, ?string $month = null): int {
        $month = $month ?: date('Y-m');
        Database::execute(
            "INSERT INTO manual_deductions (tenant_id, employee_id, batch_id, amount, reason, month, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?)",
            [$tenantId, $employeeId, $batchId, $amount, $reason, $month, $createdBy]
        );
        return (int) Database::lastInsertId();
    }

    public static function getManualByEmployeeMonth(int $employeeId, string $month, int $tenantId): array {
        return Database::fetchAll(
            "SELECT md.*, a.name AS created_by_name
             FROM manual_deductions md
             LEFT JOIN admins a ON a.id = md.created_by
             WHERE md.employee_id = ? AND md.month = ? AND md.tenant_id = ?
             ORDER BY md.created_at DESC",
            [$employeeId, $month, $tenantId]
        );
    }

    public static function findManualById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM manual_deductions WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function updateManualDeduction(int $id, int $tenantId, float $amount, string $reason): bool {
        return Database::execute(
            "UPDATE manual_deductions SET amount = ?, reason = ? WHERE id = ? AND tenant_id = ?",
            [$amount, $reason, $id, $tenantId]
        ) > 0;
    }

    public static function deleteManualDeduction(int $id, int $tenantId): bool {
        return Database::execute(
            "DELETE FROM manual_deductions WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        ) > 0;
    }

    public static function updateRules(int $tenantId, array $rules): void {
        $con = Database::getInstance();
        $con->beginTransaction();
        try {
            foreach ($rules as $rule) {
                self::upsert(
                    $tenantId,
                    $rule['rule_key'],
                    $rule['rule_type'] ?? 'numeric',
                    $rule['rule_value'],
                    $rule['description'] ?? null
                );
            }
            $con->commit();
        } catch (Exception $e) {
            $con->rollBack();
            throw $e;
        }
    }

    // ── Tiered late-arrival deductions ──────────────────────────────────

    /** Late tiers for a tenant, ascending by threshold (ladder order). */
    public static function getLateTiers(int $tenantId): array {
        return Database::fetchAll(
            "SELECT id, threshold_minutes, deduction_days
             FROM late_deduction_tiers
             WHERE tenant_id = ?
             ORDER BY threshold_minutes ASC",
            [$tenantId]
        );
    }

    /**
     * Atomically persist the deduction config: the late tier ladder plus the
     * scalar rules (late_type, absence_multiplier). $tiers is a list of
     * ['threshold_minutes' => int, 'deduction_days' => float].
     */
    public static function saveConfig(int $tenantId, array $tiers, float $absenceDays): void {
        $con = Database::getInstance();
        $con->beginTransaction();
        try {
            self::upsert($tenantId, 'late_type', 'text', 'tiered', 'نوع خصم التأخير');
            self::upsert($tenantId, 'absence_multiplier', 'numeric', (string) $absenceDays, 'خصم الغياب (أيام لكل يوم غياب)');

            Database::execute("DELETE FROM late_deduction_tiers WHERE tenant_id = ?", [$tenantId]);
            foreach ($tiers as $tier) {
                Database::execute(
                    "INSERT INTO late_deduction_tiers (tenant_id, threshold_minutes, deduction_days)
                     VALUES (?, ?, ?)",
                    [$tenantId, (int) $tier['threshold_minutes'], (float) $tier['deduction_days']]
                );
            }
            $con->commit();
        } catch (Exception $e) {
            $con->rollBack();
            throw $e;
        }
    }
}
