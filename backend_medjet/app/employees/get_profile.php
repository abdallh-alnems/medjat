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

$activationCode = null;
$activationExpiresAt = null;
if ($employee['status'] === 'pending_activation') {
    $codeRow = ActivationCodeModel::findActive((int) $employee['id']);
    $activationCode = $codeRow['code'] ?? null;
    $activationExpiresAt = $codeRow['expires_at'] ?? null;
}

$categories = EmployeeCategoryModel::getEmployeeCategories((int) $employee['id'], $tenantId);

Response::success([
    'employee' => $employee,
    'documents' => $documents,
    'warnings' => $warnings,
    'leave_balance' => $leavesBalance,
    'activation_code' => $activationCode,
    'activation_expires_at' => $activationExpiresAt,
    'categories' => $categories,
]);
