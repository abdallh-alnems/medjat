<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_deduction_rules');

$input = $auth['input'];
$rules = $input['rules'] ?? [];

if (empty($rules)) {
    Response::fail('Rules array is required', 400);
}

DeductionRuleModel::updateRules($tenantId, $rules);

AuditLogModel::log($tenantId, $auth['admin_id'], 'deduction_rules.update', null, null, $rules);

Response::success(['message' => 'Deduction rules updated']);
