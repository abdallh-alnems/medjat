<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateEmployee(db());

$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];
$branchId = $auth['branch_id'];

$categoryId = null;
$catAssignments = Database::fetchAll(
    "SELECT category_id FROM employee_category_assignments WHERE employee_id = ? AND tenant_id = ? LIMIT 1",
    [$employeeId, $tenantId]
);
if (!empty($catAssignments)) {
    $categoryId = (int) $catAssignments[0]['category_id'];
}

$surveys = SurveyModel::availableForEmployee($tenantId, $employeeId, $branchId, $categoryId);

Response::success(['items' => $surveys]);
