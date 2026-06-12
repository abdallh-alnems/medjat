<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$id = (int) ($input['id'] ?? $_GET['id'] ?? 0);
Validator::required($id, 'id');

$loan = LoanModel::findById($id, $tenantId);
if (!$loan) {
    Response::notFound('Loan');
}

$wasPending = ($loan['status'] ?? '') === 'pending';

// A pending request is rejected (distinct status); an active one is cancelled.
$ok = $wasPending
    ? LoanModel::reject($id, $tenantId)
    : LoanModel::cancel($id, $tenantId);
if (!$ok) {
    Response::fail('Loan cannot be cancelled in its current state', 409);
}

AuditLogModel::log(
    $tenantId, $auth['admin_id'],
    $wasPending ? 'loan.reject' : 'loan.cancel', 'loan', $id
);

// Tell the employee. A pending request being cancelled reads as a rejection;
// an active one reads as the loan/advance being stopped.
$isAdvance = ($loan['type'] ?? 'loan') === 'advance';
$noun      = $isAdvance ? 'السلفة' : 'القرض';
$titleAr   = $wasPending ? "تم رفض طلب {$noun}" : "تم إلغاء {$noun}";
$bodyAr    = $wasPending
    ? "تم رفض طلب {$noun} الخاص بك."
    : "تم إلغاء {$noun} وإيقاف خصم الأقساط المتبقية.";
$titleEn   = $wasPending
    ? ($isAdvance ? 'Advance Request Rejected' : 'Loan Request Rejected')
    : ($isAdvance ? 'Advance Cancelled' : 'Loan Cancelled');
$bodyEn    = $wasPending
    ? 'Your request has been rejected.'
    : 'It has been cancelled and remaining installments stopped.';

try {
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'payroll', ?, ?, ?, ?, ?, 'push,in_app', NOW())",
        [$tenantId, (int) $loan['employee_id'], $titleEn, $titleAr, $bodyEn, $bodyAr,
         json_encode(['loan_id' => $id, 'action' => $wasPending ? 'reject' : 'cancel', 'type' => $loan['type'] ?? 'loan'])]
    );

    NotificationService::sendToEmployee(
        (int) $loan['employee_id'],
        $titleAr,
        $bodyAr,
        ['loan_id' => (string) $id, 'action' => $wasPending ? 'reject' : 'cancel', 'type' => (string) ($loan['type'] ?? 'loan')]
    );
} catch (Exception $e) {
    error_log('Notification insert error: ' . $e->getMessage());
}

Response::success(['message' => 'Loan cancelled']);
