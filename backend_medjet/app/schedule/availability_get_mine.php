<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requireGet();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];

$rows = EmployeeAvailabilityModel::listForEmployee($tenantId, $employeeId);

Response::success(['availability' => $rows]);
