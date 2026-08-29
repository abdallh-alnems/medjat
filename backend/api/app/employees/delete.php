<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

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

EmployeeModel::delete($employeeId, $tenantId);

// Sign the employee out of the employee app by revoking their device token.
EmployeeAuthTokenModel::revokeForEmployee($employeeId, 'service_terminated');

AuditLogModel::log($tenantId, $auth['admin_id'], 'employee.delete', 'employee', $employeeId);

Response::success(['message' => 'Employee deactivated']);
