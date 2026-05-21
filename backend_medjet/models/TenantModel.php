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
            "INSERT INTO tenants (name, domain, owner_name, owner_email, plan, is_active)
             VALUES (?, ?, ?, ?, ?, 1)",
            [
                $data['name'],
                $data['domain'] ?? null,
                $data['owner_name'],
                $data['owner_email'],
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

    public static function updateAttendanceMethods(int $id, array $methods, ?array $adminIds): void {
        Database::execute(
            "UPDATE tenants SET attendance_methods = ?, manual_attendance_admin_ids = ? WHERE id = ?",
            [json_encode($methods), $adminIds !== null ? json_encode($adminIds) : null, $id]
        );
    }

    public static function updateAllowOffline(int $id, bool $allow): void {
        Database::execute(
            "UPDATE tenants SET allow_offline_attendance = ? WHERE id = ?",
            [(int) $allow, $id]
        );
    }

    public static function getAttendanceConfig(int $id): array {
        $row = Database::fetchOne(
            "SELECT attendance_methods, manual_attendance_admin_ids FROM tenants WHERE id = ? LIMIT 1",
            [$id]
        );
        if (!$row) {
            return ['methods' => ['qr_gps'], 'admin_ids' => null];
        }
        $methods = json_decode($row['attendance_methods'], true) ?: ['qr_gps'];
        $adminIds = $row['manual_attendance_admin_ids'] !== null
            ? json_decode($row['manual_attendance_admin_ids'], true)
            : null;
        return ['methods' => $methods, 'admin_ids' => $adminIds];
    }
}
