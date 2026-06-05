<?php

final class PayrollExportTemplateModel {
    public static function listActive(int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM payroll_export_templates
             WHERE tenant_id = ? AND is_active = 1 ORDER BY name ASC",
            [$tenantId]
        );
    }

    public static function listAll(int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM payroll_export_templates
             WHERE tenant_id = ? ORDER BY name ASC",
            [$tenantId]
        );
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM payroll_export_templates WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function create(int $tenantId, array $data, int $createdBy): int {
        Database::execute(
            "INSERT INTO payroll_export_templates
                (tenant_id, name, delimiter, include_bom, include_header_row, decimal_places, columns, is_active, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)",
            [
                $tenantId,
                $data['name'],
                $data['delimiter'] ?? ',',
                isset($data['include_bom']) ? (int)$data['include_bom'] : 1,
                isset($data['include_header_row']) ? (int)$data['include_header_row'] : 1,
                (int)($data['decimal_places'] ?? 2),
                json_encode($data['columns'], JSON_UNESCAPED_UNICODE),
                $createdBy,
            ]
        );
        return (int)Database::lastInsertId();
    }

    public static function update(int $id, int $tenantId, array $data): void {
        $sets = [];
        $params = [];
        $allowed = ['name', 'delimiter', 'include_bom', 'include_header_row', 'decimal_places', 'columns'];
        foreach ($allowed as $col) {
            if (array_key_exists($col, $data)) {
                $sets[] = "$col = ?";
                $params[] = $col === 'columns'
                    ? json_encode($data[$col], JSON_UNESCAPED_UNICODE)
                    : $data[$col];
            }
        }
        if (empty($sets)) return;
        $params[] = $id;
        $params[] = $tenantId;
        Database::execute(
            "UPDATE payroll_export_templates SET " . implode(', ', $sets) . " WHERE id = ? AND tenant_id = ?",
            $params
        );
    }

    public static function delete(int $id, int $tenantId): void {
        Database::execute(
            "UPDATE payroll_export_templates SET is_active = 0 WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        );
    }
}
