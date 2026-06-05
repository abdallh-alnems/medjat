<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_recruitment');
PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$candidateId = (int) ($input['candidate_id'] ?? 0);
Validator::required($candidateId, 'candidate_id');

$candidate = CandidateModel::findById($candidateId, $tenantId);
if (!$candidate) {
    Response::notFound('Candidate');
}

if ($candidate['converted_employee_id'] !== null) {
    Response::fail('Candidate already converted', 409);
}

$branchId = (int) ($input['branch_id'] ?? 0);
Validator::required($branchId, 'branch_id');

PermissionMiddleware::checkBranchAccess($auth, $branchId);

$createData = [
    'name' => $candidate['name'],
    'branch_id' => $branchId,
    'phone' => $candidate['phone'] ?? $input['phone'] ?? null,
    'job_title' => $input['job_title'] ?? null,
    'base_salary' => round((float) ($input['base_salary'] ?? $candidate['expected_salary'] ?? 0), 2),
    'hire_date' => $input['hire_date'] ?? date('Y-m-d'),
    'work_start_time' => $input['work_start_time'] ?? '09:00:00',
    'work_end_time' => $input['work_end_time'] ?? '17:00:00',
    'annual_leave_days' => isset($input['annual_leave_days']) && $input['annual_leave_days'] !== ''
        ? (int) $input['annual_leave_days'] : null,
    'shift_id' => isset($input['shift_id']) ? (int) $input['shift_id'] : null,
    'status' => 'pending_activation',
    'national_id' => $input['national_id'] ?? null,
];

foreach (EmployeeModel::COMPLIANCE_FIELDS as $field) {
    if (isset($input[$field]) && $input[$field] !== '') {
        $createData[$field] = $input[$field];
    }
}

$employeeId = EmployeeModel::create($tenantId, $createData);

CandidateModel::attachEmployee($candidateId, $tenantId, $employeeId);

try {
    OnboardingModel::ensureDefaults($tenantId);
    OnboardingModel::generateForEmployee($tenantId, $employeeId);
} catch (Exception $e) {
    error_log('Onboarding generation error: ' . $e->getMessage());
}

AuditLogModel::log($tenantId, $auth['admin_id'], 'candidate.convert', 'candidate', $candidateId, [
    'employee_id' => $employeeId,
]);

Response::success(['employee_id' => $employeeId, 'message' => 'Candidate converted to employee']);
