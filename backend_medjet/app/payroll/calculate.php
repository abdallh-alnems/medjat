<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$employeeId = (int) ($_GET['employee_id'] ?? 0);
$month = $_GET['month'] ?? date('Y-m');

Validator::required($employeeId, 'employee_id');

$calculation = PayrollCalculator::calculate($employeeId, $month, $tenantId);

Response::success($calculation);
