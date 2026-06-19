<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$employeeId = (int) ($_GET['employee_id'] ?? 0);
$year = (int) ($_GET['year'] ?? date('Y'));

if ($employeeId <= 0) {
    Response::fail('Employee ID required', 422, 'employee_id_required');
}
if ($year < 2000 || $year > 2100) {
    Response::fail('Invalid year', 422, 'invalid_year');
}

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

// Year-to-date = sum across every saved payroll row whose `month` falls in
// the requested year. The screen surfaces this in employee profile as a
// support for tax filings and bank letters.
$rows = Database::fetchAll(
    "SELECT month, base_salary, total_deductions, total_bonuses, net_salary,
            status, approved_at, paid_at
     FROM payroll
     WHERE tenant_id = ? AND employee_id = ? AND month LIKE ?
     ORDER BY month ASC",
    [$tenantId, $employeeId, "$year-%"]
);

$totals = [
    'total_base' => 0.0,
    'total_deductions' => 0.0,
    'total_bonuses' => 0.0,
    'total_net' => 0.0,
    'months_count' => count($rows),
    'paid_count' => 0,
    'approved_count' => 0,
    'draft_count' => 0,
];
foreach ($rows as $r) {
    $totals['total_base'] += (float) $r['base_salary'];
    $totals['total_deductions'] += (float) $r['total_deductions'];
    $totals['total_bonuses'] += (float) $r['total_bonuses'];
    $totals['total_net'] += (float) $r['net_salary'];
    if ($r['status'] === 'paid') $totals['paid_count']++;
    elseif ($r['status'] === 'approved') $totals['approved_count']++;
    else $totals['draft_count']++;
}
$totals['total_base'] = round($totals['total_base'], 2);
$totals['total_deductions'] = round($totals['total_deductions'], 2);
$totals['total_bonuses'] = round($totals['total_bonuses'], 2);
$totals['total_net'] = round($totals['total_net'], 2);

Response::success([
    'year' => $year,
    'employee' => [
        'id' => (int) $employee['id'],
        'name' => $employee['name'],
        'base_salary' => (float) ($employee['base_salary'] ?? 0),
    ],
    'totals' => $totals,
    'monthly' => $rows,
]);
