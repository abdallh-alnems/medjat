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
$updatableFields = array_merge(
    ['name', 'phone', 'email', 'job_title', 'base_salary', 'branch_id', 'hire_date', 'national_id', 'work_start_time', 'work_end_time', 'shift_id', 'bank_name', 'bank_account_number', 'bank_iban', 'bank_swift'],
    EmployeeModel::COMPLIANCE_FIELDS
);
$dateFields = ['hire_date', 'iqama_expiry', 'passport_expiry', 'work_permit_expiry', 'contract_start', 'contract_end', 'health_insurance_expiry'];
foreach ($updatableFields as $field) {
    if (isset($input[$field])) {
        // Empty string on a date/optional field clears it back to NULL.
        $updateData[$field] = $input[$field] === '' && in_array($field, $dateFields, true)
            ? null
            : $input[$field];
    }
}

// annual_leave_days: empty/null = inherit company default (store NULL); number = per-employee override.
if (array_key_exists('annual_leave_days', $input)) {
    $val = $input['annual_leave_days'];
    if ($val === null || $val === '') {
        $updateData['annual_leave_days'] = null;
    } else {
        $days = (int) $val;
        if ($days < 0 || $days > 366) {
            Response::fail('annual_leave_days must be between 0 and 366, or empty to inherit', 422);
        }
        $updateData['annual_leave_days'] = $days;
    }
}

if (!empty($updateData)) {
    EmployeeModel::update($employeeId, $tenantId, $updateData);
}

if (array_key_exists('category_ids', $input)) {
    $categoryIds = is_array($input['category_ids'])
        ? array_map('intval', $input['category_ids'])
        : [];
    EmployeeCategoryModel::assignToEmployee($employeeId, $tenantId, $categoryIds);
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'employee.update', 'employee', $employeeId, $updateData);

Response::success(['message' => 'Employee updated']);
