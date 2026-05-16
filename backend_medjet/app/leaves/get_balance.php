<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$employee = EmployeeModel::findByUserId($auth['user_id'], $tenantId);
if (!$employee) {
    Response::fail('Employee profile not found', 404);
}

$year = (int) ($_GET['year'] ?? date('Y'));
$balance = LeaveModel::getBalance($employee['id'], $tenantId, $year);

Response::success($balance);
