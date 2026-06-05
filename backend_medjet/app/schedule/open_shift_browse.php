<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];
$branchId = $auth['branch_id'];

$shifts = OpenShiftModel::browseForEmployee($tenantId, $employeeId, $branchId);

Response::success(['open_shifts' => $shifts]);
