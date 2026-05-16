<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$name = $input['name'] ?? null;
$branchId = (int) ($input['branch_id'] ?? 0);
$baseSalary = (float) ($input['base_salary'] ?? 0);
$jobTitle = $input['job_title'] ?? null;
$phone = $input['phone'] ?? null;
$hireDate = $input['hire_date'] ?? date('Y-m-d');

Validator::required($name, 'name');
Validator::required($branchId, 'branch_id');

PermissionMiddleware::checkBranchAccess($auth, $branchId);

$employeeId = EmployeeModel::create($tenantId, [
    'name' => $name,
    'branch_id' => $branchId,
    'phone' => $phone,
    'job_title' => $jobTitle,
    'base_salary' => $baseSalary,
    'hire_date' => $hireDate,
]);

AuditLogModel::log($tenantId, $auth['user_id'], 'employee.create', 'employee', $employeeId);

Response::success(['employee_id' => $employeeId], 201);
