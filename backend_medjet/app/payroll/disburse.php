<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$month = $input['month'] ?? date('Y-m');
Validator::required($employeeId, 'employee_id');

$paidAt = $input['paid_at'] ?? null;
if ($paidAt !== null && !preg_match('/^\d{4}-\d{2}-\d{2}$/', (string) $paidAt)) {
    Response::fail('paid_at must be YYYY-MM-DD', 422);
}

// Walks generate → approve → pay for this one employee in a single call.
$res = PayrollModel::disburseEmployee($employeeId, $month, $tenantId, $auth['admin_id'], $paidAt);

AuditLogModel::log(
    $tenantId,
    $auth['admin_id'],
    'payroll.disburse',
    'payroll',
    $res['payroll_id'] ?? null,
    ['employee_id' => $employeeId, 'month' => $month, 'result' => $res['result']]
);

PayrollCache::invalidate($tenantId);

// Notify the employee on their mobile app — only on a real payment transition.
if (($res['result'] ?? '') === 'paid') {
    try {
        $info = Database::fetchOne(
            "SELECT admin_id FROM employees WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$employeeId, $tenantId]
        );
        if ($info && !empty($info['admin_id'])) {
            NotificationService::sendToUser(
                (int) $info['admin_id'],
                'تم دفع راتبك',
                "تم تأكيد دفع راتب شهر {$month}.",
                ['type' => 'payroll_paid', 'month' => $month]
            );
        }
    } catch (Throwable $e) {
        error_log('Notify employee (disburse): ' . $e->getMessage());
    }
}

Response::success([
    'result' => $res['result'] ?? 'skipped',
    'payroll_id' => $res['payroll_id'] ?? null,
    'message' => 'Salary disbursed',
]);
