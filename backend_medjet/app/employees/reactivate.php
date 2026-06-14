<?php
/**
 * POST /app/employees/reactivate.php   body: { employee_id }
 *
 * Re-hires a terminated employee: restores them to `pending_activation`, clears
 * the termination markers, and removes the previous end-of-service settlement so
 * a future termination starts from a clean draft. Logged to the audit trail.
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}
if (($employee['status'] ?? '') !== 'terminated') {
    Response::fail('هذا الموظف ليس منتهي الخدمة', 409, 'not_terminated');
}

$ok = EmployeeModel::reactivate($employeeId, $tenantId);
if (!$ok) {
    Response::fail('تعذر إعادة تعيين الموظف', 409, 'reactivate_failed');
}

// Reset the end-of-service record so the employment cycle starts fresh.
EmployeeSettlementModel::deleteForEmployee($employeeId, $tenantId);

// Issue a fresh activation code so the re-hired employee can sign back in
// (status is now pending_activation; the old device token was revoked at
// termination, so they re-link a device with this code).
$activation = ActivationCodeModel::generate($tenantId, $employeeId);
$expiresAt = gmdate('Y-m-d\TH:i:s\Z', strtotime('+24 hours'));

AuditLogModel::log($tenantId, $auth['admin_id'], 'employee.reactivate', 'employee', $employeeId, [
    'name'           => $employee['name'] ?? null,
    'previous_terminated_at' => $employee['terminated_at'] ?? null,
]);

Response::success([
    'message'         => 'تمت إعادة تعيين الموظف بنجاح',
    'employee'        => EmployeeModel::findById($employeeId, $tenantId),
    'activation_code' => $activation['code'],
    'activation_token' => $activation['token'],
    'join_link'       => ActivationCodeModel::buildJoinLink($activation['token']),
    'expires_at'      => $expiresAt,
    'login_phone'     => $employee['phone'] ?? null,
]);
