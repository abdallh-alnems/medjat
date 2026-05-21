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

$claim = ExpenseModel::findById($id, $tenantId);
if (!$claim) {
    Response::notFound('Expense claim');
}
if ($claim['status'] !== 'pending') {
    Response::fail('Only pending claims can be approved', 409);
}

ExpenseModel::approve($id, $tenantId, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'expense.approve', 'expense', $id);

try {
    Database::execute(
        "INSERT INTO notifications (tenant_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, created_at)
         VALUES (?, ?, 'payroll', 'Expense Approved', 'تمت الموافقة على المصروف', 'Your expense claim has been approved.', 'تمت الموافقة على مطالبة المصروفات الخاصة بك.', ?, 'in_app', NOW())",
        [$tenantId, (int) $claim['employee_id'], json_encode(['expense_id' => $id, 'action' => 'approve'])]
    );
} catch (Exception $e) {
    error_log('Notification insert error: ' . $e->getMessage());
}

Response::success(['message' => 'Expense approved']);
