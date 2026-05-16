<?php

final class AuditLogModel {
    public static function log(int $tenantId, int $userId, string $action, ?string $targetType = null, $targetId = null, ?array $payload = null): void {
        try {
            Database::execute(
                "INSERT INTO audit_log (tenant_id, user_id, action, target_type, target_id, payload, ip) VALUES (?,?,?,?,?,?,?)",
                [
                    $tenantId,
                    $userId,
                    $action,
                    $targetType,
                    $targetId !== null ? (string) $targetId : null,
                    $payload ? json_encode($payload, JSON_UNESCAPED_UNICODE) : null,
                    $_SERVER['REMOTE_ADDR'] ?? null,
                ]
            );
        } catch (Exception $e) {
            error_log("Audit log failed: " . $e->getMessage());
        }
    }

    public static function getByTenant(int $tenantId, int $page = 1, int $limit = 50): array {
        $offset = ($page - 1) * $limit;
        $items = Database::fetchAll(
            "SELECT * FROM audit_log WHERE tenant_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?",
            [$tenantId, $limit, $offset]
        );
        return ['items' => $items, 'page' => $page];
    }

    public static function getByUser(int $userId, int $tenantId, int $page = 1, int $limit = 50): array {
        $offset = ($page - 1) * $limit;
        $items = Database::fetchAll(
            "SELECT * FROM audit_log WHERE user_id = ? AND tenant_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?",
            [$userId, $tenantId, $limit, $offset]
        );
        return ['items' => $items, 'page' => $page];
    }
}
