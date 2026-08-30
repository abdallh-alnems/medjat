<?php

final class BonusRuleModel {
    public static function getActiveByTenant(int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM bonus_rules WHERE tenant_id = ? AND is_active = 1 ORDER BY rule_key ASC",
            [$tenantId]
        );
    }

    public static function upsert(int $tenantId, string $ruleKey, string $ruleType, $ruleValue, ?string $description = null): void {
        Database::execute(
            "INSERT INTO bonus_rules (tenant_id, rule_key, rule_type, rule_value, description, is_active)
             VALUES (?, ?, ?, ?, ?, 1)
             ON DUPLICATE KEY UPDATE rule_type = VALUES(rule_type), rule_value = VALUES(rule_value), description = VALUES(description)",
            [$tenantId, $ruleKey, $ruleType, $ruleValue, $description]
        );
    }

    public static function addManualBonus(int $employeeId, int $tenantId, float $amount, string $reason, int $createdBy, ?int $batchId = null, ?string $month = null): int {
        $month = $month ?: date('Y-m');
        Database::execute(
            "INSERT INTO manual_bonuses (tenant_id, employee_id, batch_id, amount, reason, month, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?)",
            [$tenantId, $employeeId, $batchId, $amount, $reason, $month, $createdBy]
        );
        return (int) Database::lastInsertId();
    }

    public static function getManualByEmployeeMonth(int $employeeId, string $month, int $tenantId): array {
        return Database::fetchAll(
            "SELECT mb.*, a.name AS created_by_name
             FROM manual_bonuses mb
             LEFT JOIN admins a ON a.id = mb.created_by
             WHERE mb.employee_id = ? AND mb.month = ? AND mb.tenant_id = ?
             ORDER BY mb.created_at DESC",
            [$employeeId, $month, $tenantId]
        );
    }

    public static function findManualById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM manual_bonuses WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function updateManualBonus(int $id, int $tenantId, float $amount, string $reason): bool {
        return Database::execute(
            "UPDATE manual_bonuses SET amount = ?, reason = ? WHERE id = ? AND tenant_id = ?",
            [$amount, $reason, $id, $tenantId]
        ) > 0;
    }

    public static function deleteManualBonus(int $id, int $tenantId): bool {
        return Database::execute(
            "DELETE FROM manual_bonuses WHERE id = ? AND tenant_id = ?",
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
}
