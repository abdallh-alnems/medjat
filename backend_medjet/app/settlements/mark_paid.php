<?php
/**
 * POST /app/settlements/mark_paid.php   body: { employee_id }
 *
 * Marks an approved settlement as paid (records paid_at). The settlement must
 * already be approved.
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');

$settlement = EmployeeSettlementModel::getForEmployee($employeeId, $tenantId);
if (!$settlement) {
    Response::fail('لا توجد تسوية محفوظة لهذا الموظف', 404, 'no_settlement');
}
if ($settlement['status'] === 'draft') {
    Response::fail('يجب اعتماد التسوية أولاً', 409, 'not_approved');
}
if ($settlement['status'] === 'paid') {
    Response::fail('التسوية مدفوعة بالفعل', 409, 'already_paid');
}

if (!EmployeeSettlementModel::markPaid((int) $settlement['id'], $tenantId)) {
    Response::fail('تعذر تحديث التسوية', 409, 'mark_paid_failed');
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'settlement.mark_paid', 'employee', $employeeId, [
    'settlement_id' => (int) $settlement['id'],
]);

Response::success([
    'message'    => 'تم تسجيل صرف التسوية',
    'settlement' => EmployeeSettlementModel::findById((int) $settlement['id'], $tenantId),
]);
