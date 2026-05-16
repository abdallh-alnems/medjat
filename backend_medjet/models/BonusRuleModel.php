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

    public static function addManualBonus(int $employeeId, int $tenantId, float $amount, string $reason, int $createdBy): int {
        Database::execute(
            "INSERT INTO manual_bonuses (tenant_id, employee_id, amount, reason, month, created_by)
             VALUES (?, ?, ?, ?, DATE_FORMAT(NOW(), '%Y-%m'), ?)",
            [$tenantId, $employeeId, $amount, $reason, $createdBy]
        );
        return (int) Database::lastInsertId();
    }

    public static function getManualByEmployeeMonth(int $employeeId, string $month, int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM manual_bonuses WHERE employee_id = ? AND month = ? AND tenant_id = ? ORDER BY created_at DESC",
            [$employeeId, $month, $tenantId]
        );
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
