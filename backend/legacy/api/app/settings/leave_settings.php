<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $tenant = TenantModel::findById($tenantId);
    if (!$tenant) {
        Response::notFound('Tenant');
    }

    // Carryover details come from the tenant-level policy row; fall back to the
    // legacy single column when no policy has been saved yet.
    $policy = LeaveCarryoverPolicyModel::getTenantPolicy($tenantId);
    $legacyMax = $tenant['leave_carryover_max_days'] !== null ? (int) $tenant['leave_carryover_max_days'] : null;

    if ($policy) {
        $enabled = (int) $policy['carryover_enabled'] === 1;
        $maxDays = $policy['carryover_max_days'] !== null ? (int) $policy['carryover_max_days'] : null;
        $expiryMonths = $policy['expiry_months'] !== null ? (int) $policy['expiry_months'] : null;
        $encashExcess = (int) $policy['encash_excess'] === 1;
        $legalMin = $policy['legal_min_carry_days'] !== null ? (int) $policy['legal_min_carry_days'] : null;
    } else {
        $enabled = $legacyMax !== null;
        $maxDays = $legacyMax;
        $expiryMonths = null;
        $encashExcess = false;
        $legalMin = null;
    }

    Response::success([
        'default_annual_leave_days' => (int) ($tenant['default_annual_leave_days'] ?? 0),
        'leave_carryover_max_days' => $enabled ? $maxDays : null,
        'carryover_enabled' => $enabled,
        'carryover_expiry_months' => $expiryMonths,
        'carryover_encash_excess' => $encashExcess,
        'carryover_legal_min_days' => $legalMin,
        'auto_rollover_enabled' => (int) ($tenant['auto_rollover_enabled'] ?? 0) === 1,
        'apply_legal_seniority_entitlement' => (int) ($tenant['apply_legal_seniority_entitlement'] ?? 1) === 1,
    ]);
}

if ($method === 'POST' || $method === 'PUT') {
    PermissionMiddleware::check($auth, 'manage_company_settings');

    $input = $auth['input'];
    $updateData = [];

    if (isset($input['default_annual_leave_days'])) {
        $days = (int) $input['default_annual_leave_days'];
        if ($days < 0 || $days > 366) {
            Response::fail('default_annual_leave_days must be between 0 and 366', 422, 'default_annual_leave_days_between');
        }
        $updateData['default_annual_leave_days'] = $days;
    }

    if (array_key_exists('auto_rollover_enabled', $input)) {
        $updateData['auto_rollover_enabled'] = !empty($input['auto_rollover_enabled']) ? 1 : 0;
    }
    if (array_key_exists('apply_legal_seniority_entitlement', $input)) {
        $updateData['apply_legal_seniority_entitlement'] = !empty($input['apply_legal_seniority_entitlement']) ? 1 : 0;
    }

    // ── Tenant-level carryover policy ────────────────────────────────
    // Driven by `carryover_enabled`; `leave_carryover_max_days` is the cap.
    $touchPolicy = array_key_exists('leave_carryover_max_days', $input)
        || array_key_exists('carryover_enabled', $input)
        || array_key_exists('carryover_expiry_months', $input)
        || array_key_exists('carryover_encash_excess', $input)
        || array_key_exists('carryover_legal_min_days', $input);

    if ($touchPolicy) {
        $rawMax = $input['leave_carryover_max_days'] ?? null;
        $enabled = array_key_exists('carryover_enabled', $input)
            ? !empty($input['carryover_enabled'])
            : ($rawMax !== null && $rawMax !== '');

        $maxDays = ($rawMax === null || $rawMax === '') ? null : (int) $rawMax;
        if ($maxDays !== null && ($maxDays < 0 || $maxDays > 366)) {
            Response::fail('leave_carryover_max_days must be between 0 and 366, or null', 422, 'leave_carryover_max_days_between');
        }

        $expiryMonths = nullableInt($input['carryover_expiry_months'] ?? null, 'carryover_expiry_months', 0, 60);
        $legalMin = nullableInt($input['carryover_legal_min_days'] ?? null, 'carryover_legal_min_days', 0, 366);
        $encashExcess = !empty($input['carryover_encash_excess']);

        LeaveCarryoverPolicyModel::upsert($tenantId, [
            'scope_type' => 'tenant',
            'scope_id' => null,
            'min_seniority_months' => 0,
            'carryover_enabled' => $enabled ? 1 : 0,
            'carryover_max_days' => $maxDays,
            'expiry_months' => $expiryMonths,
            'encash_excess' => $encashExcess ? 1 : 0,
            'legal_min_carry_days' => $legalMin,
        ]);

        // Keep the legacy column in sync (resolver fallback + back-compat reads).
        $updateData['leave_carryover_max_days'] = $enabled ? $maxDays : null;
    }

    if (empty($updateData) && !$touchPolicy) {
        Response::fail('No leave settings provided', 422, 'leave_settings_provided');
    }

    if (!empty($updateData)) {
        TenantModel::update($tenantId, $updateData);
    }

    AuditLogModel::log($tenantId, $auth['admin_id'], 'tenant.update_leave_settings', 'tenant', $tenantId, $input);

    Response::success(['message' => 'Leave settings updated']);
}

Response::fail('Method not allowed', 405, 'method_not_allowed');

/** Parse an optional int that may be null/empty; validates the range when present. */
function nullableInt($value, string $field, int $min, int $max): ?int {
    if ($value === null || $value === '') {
        return null;
    }
    $n = (int) $value;
    if ($n < $min || $n > $max) {
        Response::fail("$field must be between $min and $max, or null", 422, 'between_null');
    }
    return $n;
}
