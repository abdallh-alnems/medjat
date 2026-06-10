<?php
require_once __DIR__ . '/../../config/bootstrap.php';

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

$id = BonusRuleModel::addManualBonus($employeeId, $tenantId, $amount, $reason, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'bonus.manual', 'employee', $employeeId, ['amount' => $amount]);

PayrollCache::invalidate($tenantId);

// Notify the employee that a bonus was added.
if (!empty($employee['admin_id'])) {
    try {
        NotificationService::sendToUser(
            (int) $employee['admin_id'],
            'مكافأة جديدة',
            "تمت إضافة مكافأة بقيمة {$amount} لراتبك.",
            ['type' => 'bonus_added', 'amount' => $amount, 'reason' => $reason]
        );
    } catch (Throwable $e) {
        error_log('Notify employee (bonus): ' . $e->getMessage());
    }
}

Response::success(['id' => $id, 'message' => 'Manual bonus added']);
