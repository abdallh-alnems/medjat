<?php
// Employee-facing: an employee requests a salary advance (سلفة). It lands as a
// pending advance the same way an admin-created one does, so the existing
// management loans screen lists it and can approve/reject it.
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];

$input             = $auth['input'];
$totalAmount       = (float) ($input['total_amount'] ?? 0);
$installmentsCount = (int) ($input['installments_count'] ?? 1);
$startMonth        = $input['start_month'] ?? date('Y-m');
$reason            = $input['reason'] ?? null;

Validator::required($totalAmount, 'total_amount');
Validator::numeric($totalAmount, 'total_amount', 0.01);
if ($installmentsCount < 1) {
    $installmentsCount = 1;
}
if (!preg_match('/^\d{4}-\d{2}$/', $startMonth)) {
    Response::fail('start_month must be in YYYY-MM format', 422, 'invalid_start_month');
}
// The deduction can't start in a past month (YYYY-MM sorts lexically).
if ($startMonth < date('Y-m')) {
    Response::fail('شهر بداية الخصم لا يمكن أن يكون في الماضي', 422, 'start_month_in_past');
}

// Soft cap so an employee can't spam pending advance requests.
if (LoanModel::countPendingForEmployee((int) $employee['id'], $tenantId) >= 3) {
    Response::fail('لديك طلبات سلفة معلّقة بالفعل', 409, 'advance_pending_limit');
}

$installmentAmount = round($totalAmount / $installmentsCount, 2);

$id = LoanModel::create(
    $tenantId,
    (int) $employee['id'],
    'advance',
    $totalAmount,
    $installmentAmount,
    $installmentsCount,
    $startMonth,
    $reason,
    null // requested by the employee, no admin author
);

AuditLogModel::log($tenantId, null, 'loan.request', 'loan', $id, [
    'type'         => 'advance',
    'total_amount' => $totalAmount,
    'installments' => $installmentsCount,
    'by_employee'  => (int) $employee['id'],
]);

// Whole amounts read as "1,000"; only keep decimals when there actually are any.
$amountLabel = (fmod($totalAmount, 1.0) === 0.0)
    ? number_format($totalAmount, 0)
    : number_format($totalAmount, 2);

try {
    $recipients = SmartAlertService::recipientsForBranch(
        $tenantId, $employee['branch_id'] ?? null, 'manage_payroll'
    );
    foreach ($recipients as $rid) {
        SmartAlertService::dispatch(
            $rid, 'payroll_events', 'payroll',
            'طلب سلفة جديد',
            "طلب سلفة جديد من {$employee['name']} بقيمة {$amountLabel}",
            'New advance request',
            "New advance request from {$employee['name']} for {$amountLabel}",
            ['loan_id' => $id, 'employee_id' => (int) $employee['id'], 'type' => 'advance'],
            "advance:{$id}"
        );
    }
} catch (Throwable $e) {
    error_log('SmartAlert advance request: ' . $e->getMessage());
}

Response::success([
    'loan_id'            => $id,
    'installment_amount' => $installmentAmount,
    'message'            => 'Advance request submitted',
]);
