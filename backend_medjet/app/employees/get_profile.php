<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$employee = EmployeeModel::findByAdminId($auth['admin_id'], $tenantId);
if (!$employee) {
    Response::fail('Employee profile not found', 404);
}

$documents = DocumentModel::getByEmployee($employee['id'], $tenantId);
$warnings = WarningModel::getByEmployee($employee['id'], $tenantId);
$leavesBalance = LeaveModel::getBalance($employee['id'], $tenantId, (int) date('Y'));

Response::success([
    'employee' => $employee,
    'documents' => $documents,
    'warnings' => $warnings,
    'leave_balance' => $leavesBalance,
]);
