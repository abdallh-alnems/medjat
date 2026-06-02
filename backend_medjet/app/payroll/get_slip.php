<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];

$month = $_GET['month'] ?? date('Y-m');
$slip = PayrollModel::getSlip($employee['id'], $month, $tenantId);

if (!$slip) {
    Response::notFound('Payroll slip');
}

Response::success($slip);
