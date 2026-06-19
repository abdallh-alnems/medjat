<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_leaves');

$input = $auth['input'];

$scopeType = $input['scope_type'] ?? '';
if (!in_array($scopeType, ['branch', 'category', 'employee'], true)) {
    // Tenant-level policy is managed via settings/leave_settings.php.
    Response::fail('scope_type must be branch, category or employee', 422, 'scope_type_branch_category_employee');
}

$scopeId = isset($input['scope_id']) ? (int) $input['scope_id'] : 0;
Validator::required($scopeId, 'scope_id');

$minSeniority = isset($input['min_seniority_months']) ? max(0, (int) $input['min_seniority_months']) : 0;

$enabled = !empty($input['carryover_enabled']);

$maxDays = null;
if (isset($input['carryover_max_days']) && $input['carryover_max_days'] !== '' && $input['carryover_max_days'] !== null) {
    $maxDays = (int) $input['carryover_max_days'];
    if ($maxDays < 0 || $maxDays > 366) {
        Response::fail('carryover_max_days must be between 0 and 366', 422, 'carryover_max_days_between_0');
    }
}

$expiryMonths = null;
if (isset($input['expiry_months']) && $input['expiry_months'] !== '' && $input['expiry_months'] !== null) {
    $expiryMonths = (int) $input['expiry_months'];
    if ($expiryMonths < 0 || $expiryMonths > 60) {
        Response::fail('expiry_months must be between 0 and 60', 422, 'expiry_months_between_0_60');
    }
}

$legalMin = null;
if (isset($input['legal_min_carry_days']) && $input['legal_min_carry_days'] !== '' && $input['legal_min_carry_days'] !== null) {
    $legalMin = (int) $input['legal_min_carry_days'];
    if ($legalMin < 0 || $legalMin > 366) {
        Response::fail('legal_min_carry_days must be between 0 and 366', 422, 'legal_min_carry_days_between');
    }
}

LeaveCarryoverPolicyModel::upsert($tenantId, [
    'scope_type' => $scopeType,
    'scope_id' => $scopeId,
    'min_seniority_months' => $minSeniority,
    'carryover_enabled' => $enabled ? 1 : 0,
    'carryover_max_days' => $maxDays,
    'expiry_months' => $expiryMonths,
    'encash_excess' => !empty($input['encash_excess']) ? 1 : 0,
    'legal_min_carry_days' => $legalMin,
]);

AuditLogModel::log($tenantId, $auth['admin_id'], 'leave.carryover_policy.save', $scopeType, $scopeId, $input);

Response::success(['message' => 'Carryover policy saved']);
