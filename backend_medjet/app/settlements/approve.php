<?php
/**
 * POST /app/settlements/approve.php   body: { employee_id }  (or { settlement_id })
 *
 * Approves the draft settlement: freezes the computed figures into `breakdown`
 * and ends the employee's service (status='terminated', terminated_at = the
 * settlement's last working day). Locked afterwards.
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

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$settlement = EmployeeSettlementModel::getForEmployee($employeeId, $tenantId);
if (!$settlement) {
    Response::fail('لا توجد تسوية محفوظة لهذا الموظف', 404, 'no_settlement');
}
if ($settlement['status'] !== 'draft') {
    Response::fail('التسوية معتمدة بالفعل', 409, 'already_approved');
}

// Freeze the full settlement row (minus volatile audit columns) as the snapshot.
$snapshot = $settlement;
unset($snapshot['created_by_name'], $snapshot['approved_by_name']);

$ok = EmployeeSettlementModel::approve(
    (int) $settlement['id'], $tenantId, $auth['admin_id'], $snapshot
);
if (!$ok) {
    Response::fail('تعذر اعتماد التسوية', 409, 'approve_failed');
}

// End the employee's service as of the last working day.
EmployeeModel::terminate($employeeId, $tenantId, $settlement['last_working_day']);

// Force the employee out of the employee app: revoking their device token makes
// the next request fail authentication, signing them out automatically.
EmployeeAuthTokenModel::revokeForEmployee($employeeId, 'service_terminated');

AuditLogModel::log($tenantId, $auth['admin_id'], 'settlement.approve', 'employee', $employeeId, [
    'settlement_id'    => (int) $settlement['id'],
    'net_amount'       => (float) $settlement['net_amount'],
    'last_working_day' => $settlement['last_working_day'],
    'reason'           => $settlement['reason'],
]);

Response::success([
    'message'    => 'تم اعتماد التسوية وإنهاء الخدمة',
    'settlement' => EmployeeSettlementModel::findById((int) $settlement['id'], $tenantId),
]);
