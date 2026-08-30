<?php
/**
 * GET /app/settlements/preview.php?employee_id=&last_working_day=
 *
 * Returns the freshly-computed suggested settlement figures for an employee as
 * of a given last working day, without saving anything. Used by the settlement
 * page to recalculate when HR changes the last working day. Does not overwrite
 * any saved draft.
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$employeeId = (int) ($_GET['employee_id'] ?? 0);
$lastWorkingDay = $_GET['last_working_day'] ?? date('Y-m-d');

if ($employeeId <= 0) {
    Response::fail('Employee ID required', 422, 'employee_id_required');
}
Validator::date($lastWorkingDay, 'last_working_day');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$suggested = SettlementCalculator::compute($employee, $tenantId, $lastWorkingDay);

Response::success([
    'employee' => [
        'id'   => (int) $employee['id'],
        'name' => $employee['name'],
    ],
    'last_working_day' => $lastWorkingDay,
    'suggested'        => $suggested,
]);
