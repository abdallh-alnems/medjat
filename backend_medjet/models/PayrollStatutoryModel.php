<?php

final class PayrollStatutoryModel {
    public static function get(int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM payroll_statutory_settings WHERE tenant_id = ? LIMIT 1",
            [$tenantId]
        );
    }

    public static function upsert(int $tenantId, array $data): void {
        $existing = self::get($tenantId);

        $fields = [
            'social_insurance_enabled' => isset($data['social_insurance_enabled']) ? (int) $data['social_insurance_enabled'] : 0,
            'si_employee_rate' => $data['si_employee_rate'] ?? null,
            'si_min_wage' => $data['si_min_wage'] ?? null,
            'si_max_wage' => $data['si_max_wage'] ?? null,
            'income_tax_enabled' => isset($data['income_tax_enabled']) ? (int) $data['income_tax_enabled'] : 0,
            'income_tax_brackets' => isset($data['income_tax_brackets']) ? json_encode($data['income_tax_brackets'], JSON_UNESCAPED_UNICODE) : null,
            'tax_personal_exemption' => $data['tax_personal_exemption'] ?? null,
            'eosb_enabled' => isset($data['eosb_enabled']) ? (int) $data['eosb_enabled'] : 0,
            'eosb_days_per_year' => $data['eosb_days_per_year'] ?? null,
        ];

        if ($existing) {
            $sets = [];
            $values = [];
            foreach ($fields as $col => $val) {
                $sets[] = "{$col} = ?";
                $values[] = $val;
            }
            $values[] = $tenantId;
            Database::execute(
                "UPDATE payroll_statutory_settings SET " . implode(', ', $sets) . " WHERE tenant_id = ?",
                $values
            );
        } else {
            $cols = array_keys($fields);
            $placeholders = array_fill(0, count($cols), '?');
            $values = array_values($fields);
            array_unshift($cols, 'tenant_id');
            array_unshift($values, $tenantId);
            array_unshift($placeholders, '?');
            Database::execute(
                "INSERT INTO payroll_statutory_settings (" . implode(', ', $cols) . ") VALUES (" . implode(', ', $placeholders) . ")",
                $values
            );
        }
    }

    public static function getDefaults(): array {
        return [
            'social_insurance_enabled' => 0,
            'si_employee_rate' => null,
            'si_min_wage' => null,
            'si_max_wage' => null,
            'income_tax_enabled' => 0,
            'income_tax_brackets' => null,
            'tax_personal_exemption' => null,
            'eosb_enabled' => 0,
            'eosb_days_per_year' => null,
        ];
    }
}
