<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();

$user = Auth::authenticateEmployee(Database::getInstance());
$employeeId = $user['employee_id'];
$tenantId = $user['tenant_id'];
$branchId = $user['branch_id'];

if (!$branchId) {
    Response::fail('Employee is not assigned to a branch', 400);
}

$qrToken = StationQrTokenService::generate($employeeId, $tenantId, $branchId);

Response::success([
    'qr_token' => $qrToken,
    'expires_in' => 30,
]);
