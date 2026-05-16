<?php

final class TenantModel {
    public static function findById(int $id): ?array {
        return Database::fetchOne(
            "SELECT * FROM tenants WHERE id = ? LIMIT 1",
            [$id]
        );
    }

    public static function findByDomain(string $domain): ?array {
        return Database::fetchOne(
            "SELECT * FROM tenants WHERE domain = ? AND is_active = 1 LIMIT 1",
            [$domain]
        );
    }

    public static function create(array $data): int {
        Database::execute(
            "INSERT INTO tenants (name, name_ar, domain, owner_name, owner_email, owner_phone, plan, is_active)
             VALUES (?, ?, ?, ?, ?, ?, ?, 1)",
            [
                $data['name'],
                $data['name_ar'] ?? null,
                $data['domain'] ?? null,
                $data['owner_name'],
                $data['owner_email'],
                $data['owner_phone'],
                $data['plan'] ?? 'starter',
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function update(int $id, array $data): void {
        $fields = [];
        $values = [];
        foreach ($data as $key => $value) {
            $fields[] = "{$key} = ?";
            $values[] = $value;
        }
        $values[] = $id;
        Database::execute(
            "UPDATE tenants SET " . implode(', ', $fields) . " WHERE id = ?",
            $values
        );
    }

    public static function activate(int $id): void {
        Database::execute("UPDATE tenants SET is_active = 1 WHERE id = ?", [$id]);
    }

    public static function deactivate(int $id): void {
        Database::execute("UPDATE tenants SET is_active = 0 WHERE id = ?", [$id]);
    }

    public static function getAll(int $page = 1, int $limit = 20): array {
        $offset = ($page - 1) * $limit;
        $items = Database::fetchAll(
            "SELECT * FROM tenants ORDER BY created_at DESC LIMIT ? OFFSET ?",
            [$limit, $offset]
        );
        $total = Database::fetchOne("SELECT COUNT(*) as count FROM tenants")['count'];
        return ['items' => $items, 'total' => (int) $total, 'page' => $page];
    }

    public static function getEmployeeCount(int $tenantId): int {
        $row = Database::fetchOne(
            "SELECT COUNT(*) as count FROM employees WHERE tenant_id = ?",
            [$tenantId]
        );
        return (int) ($row['count'] ?? 0);
    }

    public static function getBranchCount(int $tenantId): int {
        $row = Database::fetchOne(
            "SELECT COUNT(*) as count FROM branches WHERE tenant_id = ?",
            [$tenantId]
        );
        return (int) ($row['count'] ?? 0);
    }
}
