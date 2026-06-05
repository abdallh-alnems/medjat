<?php
/**
 * GET /app/settlements/get.php?employee_id=
 *
 * Returns the employee's saved settlement (draft/approved/paid) if any, plus a
 * freshly-computed suggestion the settlement page can use to prefill a brand
 * new settlement. When a settlement already exists the suggestion is computed
 * as of its stored last_working_day for reference.
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$employeeId = (int) ($_GET['employee_id'] ?? 0);
if ($employeeId <= 0) {
    Response::fail('Employee ID required', 422);
}

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$settlement = EmployeeSettlementModel::getForEmployee($employeeId, $tenantId);

$asOf = $settlement['last_working_day'] ?? date('Y-m-d');
$suggested = SettlementCalculator::compute($employee, $tenantId, $asOf);

Response::success([
    'employee' => [
        'id'          => (int) $employee['id'],
        'name'        => $employee['name'],
        'status'      => $employee['status'],
        'base_salary' => (float) ($employee['base_salary'] ?? 0),
        'hire_date'   => $employee['hire_date'] ?? $employee['contract_start'] ?? null,
    ],
    'settlement' => $settlement,
    'suggested'  => $suggested,
]);
