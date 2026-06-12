<?php
// Employee-facing: an employee withdraws their own still-pending advance request.
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];

$input = $auth['input'];
$id = (int) ($input['loan_id'] ?? $input['id'] ?? 0);
Validator::required($id, 'loan_id');

$loan = LoanModel::findById($id, $tenantId);
if (!$loan || (int) $loan['employee_id'] !== (int) $employee['id']) {
    Response::notFound('Advance');
}
if ($loan['status'] !== 'pending') {
    Response::fail('لا يمكن إلغاء هذا الطلب', 409, 'not_pending');
}

LoanModel::cancel($id, $tenantId);
AuditLogModel::log($tenantId, null, 'loan.cancel_request', 'loan', $id, [
    'by_employee' => (int) $employee['id'],
]);

Response::success(['message' => 'Advance request cancelled']);
