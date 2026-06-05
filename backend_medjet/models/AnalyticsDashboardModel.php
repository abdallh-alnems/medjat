<?php

final class AnalyticsDashboardModel {

    public static function getForAdmin(int $tenantId, int $adminId): ?array {
        return Database::fetchOne(
            "SELECT * FROM analytics_dashboards WHERE tenant_id = ? AND admin_id = ? LIMIT 1",
            [$tenantId, $adminId]
        );
    }

    public static function save(int $tenantId, int $adminId, string $name, array $layout): int {
        $existing = self::getForAdmin($tenantId, $adminId);

        $layoutJson = json_encode($layout, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        if ($existing) {
            Database::execute(
                "UPDATE analytics_dashboards SET name = ?, layout = ? WHERE id = ? AND tenant_id = ?",
                [$name, $layoutJson, $existing['id'], $tenantId]
            );
            return (int) $existing['id'];
        }

        Database::execute(
            "INSERT INTO analytics_dashboards (tenant_id, admin_id, name, layout) VALUES (?, ?, ?, ?)",
            [$tenantId, $adminId, $name, $layoutJson]
        );
        return (int) Database::lastInsertId();
    }
}
