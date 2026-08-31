<?php
/**
 * Issue or reset an employee's kiosk fallback code.
 *
 * Gated by `manage_employees` rather than a kiosk permission: this is an
 * attribute of an employee record, and whoever maintains employee records
 * maintains it.
 *
 * The plaintext is returned exactly once. A reset invalidates the previous code
 * immediately — no grace period, because the usual reason to reset is that the
 * old one was shared with a colleague.
 *
 * Input: employee_id (required), clear (bool, to revoke without reissuing)
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$employeeId = (int) ($auth['input']['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$branchId = (int) ($employee['branch_id'] ?? 0);
if ($branchId <= 0) {
    Response::fail('Employee has no branch, so a kiosk code has no scope', 422, 'employee_without_branch');
}

if (!empty($auth['input']['clear'])) {
    KioskEmployeeCode::clearFor($employeeId, $tenantId);
    Response::success([
        'employee_id' => $employeeId,
        'cleared'     => true,
        'has_code'    => false,
    ]);
}

$code = KioskEmployeeCode::issueFor($employeeId, $tenantId, $branchId);

Response::success([
    'employee_id' => $employeeId,
    'name'        => $employee['name'],
    // Shown once. It is not recoverable from the database afterwards.
    'code'        => $code,
    'replaced_previous' => !empty($employee['kiosk_pin_hash']),
    'has_code'    => true,
]);
