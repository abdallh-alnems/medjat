<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$employee = EmployeeModel::findByAdminId($auth['admin_id'], $tenantId);
if (!$employee) {
    Response::fail('Employee profile not found', 404);
}

$month = $_GET['month'] ?? date('Y-m');
$slip = PayrollModel::getSlip($employee['id'], $month, $tenantId);

if (!$slip) {
    Response::notFound('Payroll slip');
}

Response::success($slip);
