<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$employeeId = (int) ($_GET['employee_id'] ?? 0);
Validator::required($employeeId, 'employee_id');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$settings = PayrollStatutoryModel::get($tenantId);
if (!$settings || !$settings['eosb_enabled']) {
    Response::success([
        'employee_id' => $employeeId,
        'enabled' => false,
        'message' => 'EOSB is not enabled for this company',
    ]);
}

$eosbDaysPerYear = (float) $settings['eosb_days_per_year'];
if ($eosbDaysPerYear <= 0) {
    Response::fail('Invalid eosb_days_per_year setting', 422, 'invalid_eosb_days_per_year');
}

$hireDate = $employee['hire_date'] ?? null;
if (!$hireDate) {
    Response::fail('Employee has no hire_date', 422, 'employee_hire_date');
}

$hire = new DateTime($hireDate);
$now = new DateTime();
$diff = $now->diff($hire);
$yearsOfService = $diff->y + ($diff->m / 12) + ($diff->d / 365.25);

$baseSalary = (float) $employee['base_salary'];
$dailyWage = $baseSalary / 30;
$eosbAmount = round($yearsOfService * $eosbDaysPerYear * $dailyWage, 2);

Response::success([
    'employee_id' => $employeeId,
    'employee_name' => $employee['name'],
    'enabled' => true,
    'hire_date' => $hireDate,
    'years_of_service' => round($yearsOfService, 2),
    'eosb_days_per_year' => $eosbDaysPerYear,
    'daily_wage' => round($dailyWage, 2),
    'eosb_amount' => $eosbAmount,
    'breakdown' => [
        'years_of_service' => round($yearsOfService, 2),
        'x_days_per_year' => $eosbDaysPerYear,
        'x_daily_wage' => round($dailyWage, 2),
        '= total' => $eosbAmount,
    ],
]);
