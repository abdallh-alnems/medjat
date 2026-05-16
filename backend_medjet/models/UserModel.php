<?php

final class UserModel {
    public static function findByFirebaseUid(string $uid): ?array {
        return Database::fetchOne(
            "SELECT * FROM users WHERE firebase_uid = ? LIMIT 1",
            [$uid]
        );
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM users WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$id, $tenantId]
        );
    }

    public static function create(array $data): int {
        Database::execute(
            "INSERT INTO users (firebase_uid, tenant_id, branch_id, name, phone, email, role, is_active)
             VALUES (?, ?, ?, ?, ?, ?, ?, 1)",
            [
                $data['firebase_uid'],
                $data['tenant_id'],
                $data['branch_id'] ?? null,
                $data['name'],
                $data['phone'] ?? null,
                $data['email'] ?? null,
                $data['role'] ?? 'employee',
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function update(int $id, int $tenantId, array $data): void {
        $fields = [];
        $values = [];
        foreach ($data as $key => $value) {
            $fields[] = "{$key} = ?";
            $values[] = $value;
        }
        $values[] = $id;
        $values[] = $tenantId;
        Database::execute(
            "UPDATE users SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    public static function updateFcmToken(int $userId, string $token, string $platform, string $deviceId): void {
        Database::execute(
            "INSERT INTO user_devices (user_id, fcm_token, platform, device_id, is_active)
             VALUES (?, ?, ?, ?, 1)
             ON DUPLICATE KEY UPDATE fcm_token = VALUES(fcm_token), is_active = 1, updated_at = NOW()",
            [$userId, $token, $platform, $deviceId]
        );
    }

    public static function getByTenant(int $tenantId, int $page = 1, int $limit = 20, ?int $branchId = null): array {
        $sql = "SELECT id, tenant_id, branch_id, name, phone, email, role, is_active, created_at
                FROM users WHERE tenant_id = ?";
        $params = [$tenantId];

        if ($branchId) {
            $sql .= " AND branch_id = ?";
            $params[] = $branchId;
        }

        $offset = ($page - 1) * $limit;
        $sql .= " ORDER BY created_at DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;

        $items = Database::fetchAll($sql, $params);
        return ['items' => $items, 'page' => $page];
    }
}
