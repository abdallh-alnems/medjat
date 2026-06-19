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
if ($loan['status'] !== 'pending') {
    Response::fail('Only pending loans can be approved', 409, 'only_pending_loans_can_approved');
}

LoanModel::approve($id, $tenantId, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'loan.approve', 'loan', $id);

$isAdvance = ($loan['type'] ?? 'loan') === 'advance';
$titleAr = $isAdvance ? 'تمت الموافقة على السلفة' : 'تمت الموافقة على القرض';
$bodyAr  = $isAdvance
    ? 'تمت الموافقة على طلب السلفة وسيتم خصمها على أقساط.'
    : 'تمت الموافقة على القرض وسيتم خصمه على أقساط.';
$titleEn = $isAdvance ? 'Advance Approved' : 'Loan Approved';
$bodyEn  = 'Your request has been approved and will be deducted in installments.';

try {
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'payroll', ?, ?, ?, ?, ?, 'push,in_app', NOW())",
        [$tenantId, (int) $loan['employee_id'], $titleEn, $titleAr, $bodyEn, $bodyAr,
         json_encode(['loan_id' => $id, 'action' => 'approve', 'type' => $loan['type'] ?? 'loan'])]
    );

    NotificationService::sendToEmployee(
        (int) $loan['employee_id'],
        $titleAr,
        $bodyAr,
        ['loan_id' => (string) $id, 'action' => 'approve', 'type' => (string) ($loan['type'] ?? 'loan')]
    );
} catch (Exception $e) {
    error_log('Notification insert error: ' . $e->getMessage());
}

Response::success(['message' => 'Loan approved and installment schedule generated']);
