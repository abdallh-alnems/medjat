<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$payrollId = (int) ($input['payroll_id'] ?? 0);
Validator::required($payrollId, 'payroll_id');

// Re-freeze the slip with the final full-cycle figures at the moment of
// approval, so the locked amount reflects the approval decision rather than the
// earlier draft generation. After this, the slip is the source of truth and is
// no longer recalculated live. (Matches how payroll systems lock a run on
// approval.)
$slipRow = Database::fetchOne(
    "SELECT employee_id, month FROM payroll WHERE id = ? AND tenant_id = ? LIMIT 1",
    [$payrollId, $tenantId]
);
if ($slipRow) {
    $finalCalc = PayrollCalculator::calculate(
        (int) $slipRow['employee_id'],
        (string) $slipRow['month'],
        $tenantId
    );
    if (!empty($finalCalc)) {
        Database::execute(
            "UPDATE payroll
                SET base_salary = ?, total_deductions = ?, total_bonuses = ?,
                    net_salary = ?, breakdown = ?
              WHERE id = ? AND tenant_id = ?",
            [
                $finalCalc['base_salary'],
                $finalCalc['total_deductions'],
                $finalCalc['total_bonuses'],
                $finalCalc['net_salary'],
                json_encode($finalCalc, JSON_UNESCAPED_UNICODE),
                $payrollId,
                $tenantId,
            ]
        );
    }
}

PayrollModel::approve($payrollId, $tenantId, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'payroll.approve', 'payroll', $payrollId);

// Mark this slip's loan installments as paid and advance loan progress.
try {
    $slip = Database::fetchOne(
        "SELECT p.employee_id, p.month, e.admin_id, e.name AS employee_name
         FROM payroll p
         JOIN employees e ON e.id = p.employee_id
         WHERE p.id = ? AND p.tenant_id = ?",
        [$payrollId, $tenantId]
    );
    if ($slip) {
        LoanModel::settleMonth((int) $slip['employee_id'], $slip['month'], $tenantId);
        // Notify the employee on their mobile app — their salary is approved.
        if (!empty($slip['admin_id'])) {
            try {
                NotificationService::sendToUser(
                    (int) $slip['admin_id'],
                    'تم اعتماد راتبك',
                    "تم اعتماد كشف راتبك لشهر {$slip['month']}.",
                    ['type' => 'payroll_approved', 'month' => $slip['month'], 'payroll_id' => $payrollId]
                );
            } catch (Throwable $e) {
                error_log('Notify employee (approve): ' . $e->getMessage());
            }
        }
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

PayrollCache::invalidate($tenantId);

Response::success(['message' => 'Payroll approved']);
