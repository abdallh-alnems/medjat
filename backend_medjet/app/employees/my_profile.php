<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];

$employee = $auth['employee'];
$documents = DocumentModel::getByEmployee($employee['id'], $tenantId);
$leavesBalance = LeaveModel::getBalance($employee['id'], $tenantId, (int) date('Y'));

Response::success([
    'employee' => $employee,
    'documents' => $documents,
    'leave_balance' => $leavesBalance,
]);
