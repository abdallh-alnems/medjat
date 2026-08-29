<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$amount = (float) ($input['amount'] ?? 0);
$reason = trim((string) ($input['reason'] ?? ''));

Validator::required($employeeId, 'employee_id');
Validator::required($amount, 'amount');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$id = DeductionRuleModel::addManualDeduction($employeeId, $tenantId, $amount, $reason, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'deduction.manual', 'employee', $employeeId, ['amount' => $amount]);

PayrollCache::invalidate($tenantId);

// Notify the employee that a deduction was added.
if (!empty($employee['admin_id'])) {
    try {
        NotificationService::sendToUser(
            (int) $employee['admin_id'],
            'خصم جديد',
            "تمت إضافة خصم بقيمة {$amount} على راتبك.",
            ['type' => 'deduction_added', 'amount' => $amount, 'reason' => $reason]
        );
    } catch (Throwable $e) {
        error_log('Notify employee (deduction): ' . $e->getMessage());
    }
}

Response::success(['id' => $id, 'message' => 'Manual deduction added']);
