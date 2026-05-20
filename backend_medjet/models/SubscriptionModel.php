<?php

final class SubscriptionModel {
    public static function findByTenant(int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT s.*, p.name as plan_name, p.max_employees, p.max_branches
             FROM subscriptions s
             JOIN plans p ON p.id = s.plan_id
             WHERE s.tenant_id = ? LIMIT 1",
            [$tenantId]
        );
    }

    public static function create(int $tenantId, int $planId, string $startDate, string $endDate): int {
        Database::execute(
            "INSERT INTO subscriptions (tenant_id, plan_id, start_date, end_date, status) VALUES (?, ?, ?, ?, 'active')
             ON DUPLICATE KEY UPDATE plan_id = VALUES(plan_id), start_date = VALUES(start_date), end_date = VALUES(end_date), status = 'active'",
            [$tenantId, $planId, $startDate, $endDate]
        );
        return (int) Database::lastInsertId();
    }

    public static function checkLimits(int $tenantId): void {
        $sub = self::findByTenant($tenantId);
        if (!$sub) {
            Response::fail('No active subscription found', 403);
        }

        if (!in_array($sub['status'], ['active', 'trial'], true)) {
            Response::fail('Subscription is not active', 403);
        }

        if (strtotime($sub['end_date']) < time()) {
            Response::fail('Subscription has expired', 403);
        }
    }

    public static function getAll(int $page = 1, int $limit = 20): array {
        $offset = ($page - 1) * $limit;
        $items = Database::fetchAll(
            "SELECT s.*, t.name as tenant_name, p.name as plan_name
             FROM subscriptions s
             JOIN tenants t ON t.id = s.tenant_id
             JOIN plans p ON p.id = s.plan_id
             ORDER BY s.created_at DESC LIMIT ? OFFSET ?",
            [$limit, $offset]
        );
        return ['items' => $items, 'page' => $page];
    }

    public static function updateStatus(int $tenantId, string $status): void {
        Database::execute(
            "UPDATE subscriptions SET status = ? WHERE tenant_id = ?",
            [$status, $tenantId]
        );
    }
}
