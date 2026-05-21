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
if ($claim['status'] !== 'approved') {
    Response::fail('Only approved claims can be marked reimbursed', 409);
}

ExpenseModel::markReimbursed($id, $tenantId, $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'expense.reimburse', 'expense', $id);

Response::success(['message' => 'Expense marked as reimbursed']);
