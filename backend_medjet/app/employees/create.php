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
$baseSalary = (int) ($input['base_salary'] ?? 0);
$jobTitle = $input['job_title'] ?? null;
$phone = $input['phone'] ?? null;
$hireDate = $input['hire_date'] ?? date('Y-m-d');
$workStartTime = $input['work_start_time'] ?? '09:00:00';
$workEndTime = $input['work_end_time'] ?? '17:00:00';
$shiftId = isset($input['shift_id']) ? (int) $input['shift_id'] : null;
$annualLeaveDays = isset($input['annual_leave_days']) && $input['annual_leave_days'] !== ''
    ? (int) $input['annual_leave_days']
    : null;

Validator::required($name, 'name');
Validator::required($branchId, 'branch_id');

PermissionMiddleware::checkBranchAccess($auth, $branchId);

$createData = [
    'name' => $name,
    'branch_id' => $branchId,
    'phone' => $phone,
    'job_title' => $jobTitle,
    'base_salary' => $baseSalary,
    'hire_date' => $hireDate,
    'work_start_time' => $workStartTime,
    'work_end_time' => $workEndTime,
    'annual_leave_days' => $annualLeaveDays,
    'shift_id' => $shiftId,
    'status' => 'pending_activation',
    'national_id' => $input['national_id'] ?? null,
    'bank_name' => $input['bank_name'] ?? null,
    'bank_account_number' => $input['bank_account_number'] ?? null,
    'bank_iban' => $input['bank_iban'] ?? null,
    'bank_swift' => $input['bank_swift'] ?? null,
];

// Optional compliance / legal credential fields.
foreach (EmployeeModel::COMPLIANCE_FIELDS as $field) {
    if (isset($input[$field]) && $input[$field] !== '') {
        $createData[$field] = $input[$field];
    }
}

$employeeId = EmployeeModel::create($tenantId, $createData);

$categoryIds = is_array($input['category_ids'] ?? null)
    ? array_map('intval', $input['category_ids'])
    : [];
if (!empty($categoryIds)) {
    EmployeeCategoryModel::assignToEmployee($employeeId, $tenantId, $categoryIds);
}

$activationCode = ActivationCodeModel::generate($tenantId, $employeeId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'employee.create', 'employee', $employeeId);

Response::success([
    'employee_id' => $employeeId,
    'activation_code' => $activationCode,
    'activation_expires_in_hours' => 24,
], 201);
