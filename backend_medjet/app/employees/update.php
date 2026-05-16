<?php
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

if (isset($input['branch_id'])) {
    PermissionMiddleware::checkBranchAccess($auth, (int) $input['branch_id']);
}

$updateData = [];
foreach (['name', 'phone', 'email', 'job_title', 'base_salary', 'branch_id', 'hire_date', 'national_id'] as $field) {
    if (isset($input[$field])) {
        $updateData[$field] = $input[$field];
    }
}

if (!empty($updateData)) {
    EmployeeModel::update($employeeId, $tenantId, $updateData);
}

AuditLogModel::log($tenantId, $auth['user_id'], 'employee.update', 'employee', $employeeId, $updateData);

Response::success(['message' => 'Employee updated']);
