<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$payrollId = (int) ($input['payroll_id'] ?? 0);
Validator::required($payrollId, 'payroll_id');

PayrollModel::approve($payrollId, $tenantId, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'payroll.approve', 'payroll', $payrollId);

Response::success(['message' => 'Payroll approved']);
