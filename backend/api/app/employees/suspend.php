<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_employees');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$reason = trim((string) ($input['reason'] ?? ''));
$payMode = $input['pay_mode'] ?? 'unpaid';
$startDate = $input['start_date'] ?? date('Y-m-d');
$endDate = isset($input['end_date']) && $input['end_date'] !== '' ? $input['end_date'] : null;

Validator::required($employeeId, 'employee_id');
Validator::required($reason, 'reason');
Validator::enum($payMode, EmployeeSuspensionModel::PAY_MODES, 'pay_mode');
Validator::date($startDate, 'start_date');

// Partial pay requires a percentage in (0, 100); store it only for that mode.
$payPercentage = null;
if ($payMode === 'partial') {
    $payPercentage = (float) ($input['pay_percentage'] ?? -1);
    if ($payPercentage <= 0 || $payPercentage >= 100) {
        Response::fail('pay_percentage must be between 0 and 100 for partial pay', 422, 'pay_percentage_between_0_100');
    }
}

if ($endDate !== null) {
    Validator::date($endDate, 'end_date');
    if ($endDate < $startDate) {
        Response::fail('end_date must be on or after start_date', 422, 'end_date_after_start_date');
    }
}

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}
if ($employee['status'] === 'terminated') {
    Response::fail('Cannot suspend a terminated employee', 422, 'cannot_suspend_terminated_employee');
}

// One active suspension at a time.
if (EmployeeSuspensionModel::getActiveForEmployee($employeeId, $tenantId)) {
    Response::fail('Employee already has an active suspension', 409, 'employee_already_active_suspension');
}

$id = EmployeeSuspensionModel::create($tenantId, $employeeId, [
    'reason' => $reason,
    'pay_mode' => $payMode,
    'pay_percentage' => $payPercentage,
    'start_date' => $startDate,
    'end_date' => $endDate,
    'previous_status' => $employee['status'],
], $auth['admin_id']);

EmployeeModel::update($employeeId, $tenantId, ['status' => 'suspended']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'employee.suspend', 'employee', $employeeId, [
    'suspension_id' => $id,
    'pay_mode' => $payMode,
    'pay_percentage' => $payPercentage,
    'start_date' => $startDate,
    'end_date' => $endDate,
]);

Response::success(['id' => $id, 'message' => 'Employee suspended']);
