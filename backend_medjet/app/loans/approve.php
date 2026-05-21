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
    Response::fail('Only pending loans can be approved', 409);
}

LoanModel::approve($id, $tenantId, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'loan.approve', 'loan', $id);

try {
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'payroll', 'Loan Approved', 'تمت الموافقة على السلفة', 'Your loan/advance has been approved and will be deducted in installments.', 'تمت الموافقة على السلفة/القرض وسيتم خصمها على أقساط.', ?, 'in_app', NOW())",
        [$tenantId, (int) $loan['employee_id'], json_encode(['loan_id' => $id, 'action' => 'approve'])]
    );
} catch (Exception $e) {
    error_log('Notification insert error: ' . $e->getMessage());
}

Response::success(['message' => 'Loan approved and installment schedule generated']);
