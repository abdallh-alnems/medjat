<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$payrollId = (int) ($input['payroll_id'] ?? 0);
Validator::required($payrollId, 'payroll_id');

PayrollModel::approve($payrollId, $tenantId, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'payroll.approve', 'payroll', $payrollId);

// Mark this slip's loan installments as paid and advance loan progress.
try {
    $slip = Database::fetchOne(
        "SELECT employee_id, month FROM payroll WHERE id = ? AND tenant_id = ?",
        [$payrollId, $tenantId]
    );
    if ($slip) {
        LoanModel::settleMonth((int) $slip['employee_id'], $slip['month'], $tenantId);
    }
} catch (Throwable $e) {
    error_log('Loan settlement error: ' . $e->getMessage());
}

try {
    $recipients = SmartAlertService::recipientsForBranch($tenantId, null, 'manage_payroll');
    foreach ($recipients as $rid) {
        if ($rid === $auth['admin_id']) continue;
        SmartAlertService::dispatch(
            $rid, 'payroll_events', 'payroll',
            'اعتماد كشف رواتب', "تم اعتماد كشف رواتب #{$payrollId}",
            'Payroll Approved', "Payroll #{$payrollId} has been approved",
            ['payroll_id' => $payrollId],
            "payroll_approve:{$payrollId}"
        );
    }
} catch (Throwable $e) {
    error_log('SmartAlert payroll approve: ' . $e->getMessage());
}

Response::success(['message' => 'Payroll approved']);
