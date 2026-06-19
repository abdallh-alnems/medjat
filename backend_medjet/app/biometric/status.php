<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$employeeId = (int) ($_GET['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');

$status = BiometricModel::getStatus($employeeId, $tenantId);
if (!$status) Response::fail('Employee not found', 404, 'employee_not_found');

Response::success($status);
