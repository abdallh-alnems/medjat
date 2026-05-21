<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$id = (int) ($input['id'] ?? $_GET['id'] ?? 0);
$reason = $input['rejection_reason'] ?? null;
Validator::required($id, 'id');

$claim = ExpenseModel::findById($id, $tenantId);
if (!$claim) {
    Response::notFound('Expense claim');
}
if ($claim['status'] !== 'pending') {
    Response::fail('Only pending claims can be rejected', 409);
}

ExpenseModel::reject($id, $tenantId, $auth['admin_id'], $reason);

AuditLogModel::log($tenantId, $auth['admin_id'], 'expense.reject', 'expense', $id);

try {
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'payroll', 'Expense Rejected', 'تم رفض المصروف', 'Your expense claim has been rejected.', 'تم رفض مطالبة المصروفات الخاصة بك.', ?, 'in_app', NOW())",
        [$tenantId, (int) $claim['employee_id'], json_encode(['expense_id' => $id, 'action' => 'reject'])]
    );
} catch (Exception $e) {
    error_log('Notification insert error: ' . $e->getMessage());
}

Response::success(['message' => 'Expense rejected']);
