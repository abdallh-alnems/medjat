<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];

$employee = $auth['employee'];
$status = $_GET['status'] ?? null;
if ($status !== null && !in_array($status, ['pending', 'approved', 'rejected'], true)) {
    $status = null;
}

$items = LeaveModel::getByEmployee($employee['id'], $tenantId, $status);

Response::success(['items' => $items]);
