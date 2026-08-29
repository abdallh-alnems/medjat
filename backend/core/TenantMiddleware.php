<?php

final class TenantMiddleware {
    public static function getTenantId(): ?int {
        $tenantId = $_SERVER['HTTP_X_TENANT_ID'] ?? $_GET['tenant_id'] ?? null;
        if (!$tenantId) {
            $input = Validator::getJsonBody();
            $tenantId = $input['tenant_id'] ?? null;
        }
        return $tenantId ? (int) $tenantId : null;
    }

    public static function requireTenant(): int {
        $tenantId = self::getTenantId();
        if (!$tenantId) {
            Response::fail('Tenant ID is required', 400);
        }

        $tenant = TenantModel::findById($tenantId);
        if (!$tenant) {
            Response::fail('Company not found', 404);
        }

        if (!$tenant['is_active']) {
            Response::fail('Company account is suspended', 403);
        }

        return $tenantId;
    }

    public static function filterByTenant(string $table, string $alias = 't'): string {
        $tenantId = self::getTenantId();
        if ($tenantId) {
            return " AND {$alias}.tenant_id = " . (int) $tenantId;
        }
        return '';
    }
}
