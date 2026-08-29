<?php
/**
 * POST /app/settlements/save.php
 *
 * Creates or updates the DRAFT settlement for an employee with HR's edited
 * figures. Body:
 *   employee_id, reason, last_working_day, notes,
 *   base_salary, daily_rate, years_of_service, hire_date,
 *   pending_salary, gratuity_days, gratuity_amount,
 *   leave_balance_days, leave_encashment, other_additions,
 *   outstanding_loans, other_deductions,
 *   line_items: [{label, kind:'earning'|'deduction', amount}]
 *
 * Totals are recomputed server-side. An approved/paid settlement is locked.
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$employeeId = (int) ($input['employee_id'] ?? 0);
$lastWorkingDay = $input['last_working_day'] ?? null;
$reason = $input['reason'] ?? 'resignation';

Validator::required($employeeId, 'employee_id');
Validator::required($lastWorkingDay, 'last_working_day');
Validator::date($lastWorkingDay, 'last_working_day');
Validator::enum($reason, EmployeeSettlementModel::REASONS, 'reason');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}
if (($employee['status'] ?? '') === 'terminated') {
    Response::fail('الموظف منتهية خدمته بالفعل', 422, 'already_terminated');
}

$existing = EmployeeSettlementModel::getForEmployee($employeeId, $tenantId);
if ($existing && $existing['status'] !== 'draft') {
    Response::fail('لا يمكن تعديل تسوية معتمدة', 409, 'settlement_locked');
}

$settlementId = EmployeeSettlementModel::upsert($tenantId, $employeeId, [
    'reason'             => $reason,
    'notes'              => $input['notes'] ?? null,
    'last_working_day'   => $lastWorkingDay,
    'hire_date'          => $input['hire_date'] ?? null,
    'base_salary'        => $input['base_salary'] ?? 0,
    'daily_rate'         => $input['daily_rate'] ?? 0,
    'years_of_service'   => $input['years_of_service'] ?? 0,
    'pending_salary'     => $input['pending_salary'] ?? 0,
    'gratuity_days'      => $input['gratuity_days'] ?? 0,
    'gratuity_amount'    => $input['gratuity_amount'] ?? 0,
    'leave_balance_days' => $input['leave_balance_days'] ?? 0,
    'leave_encashment'   => $input['leave_encashment'] ?? 0,
    'other_additions'    => $input['other_additions'] ?? 0,
    'outstanding_loans'  => $input['outstanding_loans'] ?? 0,
    'other_deductions'   => $input['other_deductions'] ?? 0,
    'line_items'         => $input['line_items'] ?? [],
], $auth['admin_id']);

AuditLogModel::log($tenantId, $auth['admin_id'], 'settlement.save', 'employee', $employeeId, [
    'settlement_id' => $settlementId,
]);

$settlement = EmployeeSettlementModel::findById($settlementId, $tenantId);

Response::success([
    'settlement_id' => $settlementId,
    'settlement'    => $settlement,
    'message'       => 'تم حفظ التسوية',
]);
