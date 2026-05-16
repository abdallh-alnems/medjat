<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$month = $input['month'] ?? date('Y-m');
$branchId = ($input['branch_id'] ?? null) ? (int) $input['branch_id'] : null;

$results = PayrollModel::generate($tenantId, $month, $branchId);

AuditLogModel::log($tenantId, $auth['user_id'], 'payroll.generate', null, null, ['month' => $month]);

Response::success([
    'month' => $month,
    'generated_count' => count($results),
]);
