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
$baseSalary = round((float) ($input['base_salary'] ?? 0), 2);
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

if ($phone !== null && $phone !== '') {
    $normalizedPhone = Validator::phone($phone);
    if ($normalizedPhone === null) {
        Response::fail('Invalid phone number', 422, 'invalid_phone_number');
    }
    $phone = $normalizedPhone;
}

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

if (array_key_exists('weekly_off_days', $input)) {
    $createData['weekly_off_days'] = EmployeeModel::normalizeWeeklyOffDays($input['weekly_off_days']);
}

// Fixed-term employee: the date employment auto-ends. Must be a future date.
if (!empty($input['auto_terminate_at'])) {
    $endDate = Validator::date($input['auto_terminate_at'], 'auto_terminate_at');
    if ($endDate <= date('Y-m-d')) {
        Response::fail('auto_terminate_at must be a future date', 422, 'auto_terminate_at_future_date');
    }
    $createData['auto_terminate_at'] = $endDate;
}

// Optional compliance / legal credential fields.
foreach (EmployeeModel::COMPLIANCE_FIELDS as $field) {
    if (isset($input[$field]) && $input[$field] !== '') {
        $createData[$field] = $input[$field];
    }
}

// Contract end, when supplied with a start, must be strictly after it.
if (!empty($createData['contract_start']) && !empty($createData['contract_end'])
    && $createData['contract_end'] <= $createData['contract_start']) {
    Response::fail('Contract end must be after the start date', 422, 'contract_end_after_start_date');
}

$employeeId = EmployeeModel::create($tenantId, $createData);

$categoryIds = is_array($input['category_ids'] ?? null)
    ? array_map('intval', $input['category_ids'])
    : [];
if (!empty($categoryIds)) {
    EmployeeCategoryModel::assignToEmployee($employeeId, $tenantId, $categoryIds);
}

// Optional recurring monthly allowances supplied with the new employee
// (housing, transport, food…). Each one becomes an active allowance row that
// payroll emits as a bonus line every month from start_month onwards. They
// default to the hire month and run open-ended unless an end month is given.
if (is_array($input['allowances'] ?? null)) {
    $defaultStartMonth = substr($hireDate, 0, 7); // hire date is YYYY-MM-DD
    foreach ($input['allowances'] as $allowance) {
        if (!is_array($allowance)) {
            continue;
        }
        $type = trim((string) ($allowance['type'] ?? ''));
        $amount = (float) ($allowance['amount'] ?? 0);
        // Skip blank rows (no type or non-positive amount) silently so the UI
        // can submit a fixed set of optional fields without erroring.
        if ($type === '' || $amount <= 0) {
            continue;
        }

        $startMonth = (string) ($allowance['start_month'] ?? '');
        if (!preg_match('/^\d{4}-\d{2}$/', $startMonth)) {
            $startMonth = $defaultStartMonth;
        }
        $endMonth = isset($allowance['end_month']) && $allowance['end_month'] !== ''
            ? (string) $allowance['end_month'] : null;
        if ($endMonth !== null && !preg_match('/^\d{4}-\d{2}$/', $endMonth)) {
            Response::fail('allowance end_month must be YYYY-MM', 422, 'allowance_end_month_yyyy_mm');
        }
        if ($endMonth !== null && $endMonth < $startMonth) {
            Response::fail('allowance end_month cannot be before start_month', 422, 'allowance_end_month_cannot_before');
        }
        $label = isset($allowance['label']) && trim((string) $allowance['label']) !== ''
            ? trim((string) $allowance['label']) : null;

        AllowanceModel::create(
            $tenantId,
            $employeeId,
            $type,
            $amount,
            $startMonth,
            $endMonth,
            $label,
            $auth['admin_id']
        );
    }
}

// Optional per-employee document requests entered on the add-employee form.
// Each becomes an employee-scoped required document so ONLY this employee is
// asked to provide it (mirrors the custom path in employees/request_document).
if (is_array($input['requested_documents'] ?? null)) {
    foreach ($input['requested_documents'] as $doc) {
        if (!is_array($doc)) {
            continue;
        }
        $docName = trim((string) ($doc['name'] ?? ''));
        // Skip blank rows silently so the UI can submit optional fields.
        if ($docName === '') {
            continue;
        }
        $fields = [
            'name' => mb_substr($docName, 0, 100),
            'description' => isset($doc['description']) && trim((string) $doc['description']) !== ''
                ? trim((string) $doc['description']) : null,
            'scope_type' => 'employees',
            'scope_branch_id' => null,
            'is_required' => 1,
        ];
        if (!empty($doc['category'])) {
            Validator::enum($doc['category'],
                ['identity', 'contract', 'certificate', 'insurance', 'general'], 'category');
            $fields['category'] = $doc['category'];
        }
        if (isset($doc['expiry_days']) && $doc['expiry_days'] !== '' && $doc['expiry_days'] !== null) {
            $fields['expiry_days'] = (int) $doc['expiry_days'] ?: null;
        }
        $reqId = DocumentModel::addRequiredFull($tenantId, $fields);
        DocumentModel::setEmployeeScope($reqId, $tenantId, [$employeeId]);
        AuditLogModel::log($tenantId, $auth['admin_id'], 'document.request', 'employee', $employeeId, [
            'required_document_id' => $reqId,
            'custom' => true,
            'source' => 'employee_create',
        ]);
    }
}

$activation = ActivationCodeModel::generate($tenantId, $employeeId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'employee.create', 'employee', $employeeId);

try {
    OnboardingModel::ensureDefaults($tenantId);
    OnboardingModel::generateForEmployee($tenantId, $employeeId);
} catch (Exception $e) {
    error_log('Onboarding generation error: ' . $e->getMessage());
}

Response::success([
    'employee_id' => $employeeId,
    'activation_code' => $activation['code'],
    'activation_token' => $activation['token'],
    'join_link' => ActivationCodeModel::buildJoinLink($activation['token']),
    'phone' => $phone,
    'activation_expires_in_hours' => 24,
], 201);
