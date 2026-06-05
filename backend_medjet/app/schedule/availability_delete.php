<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];
$input = $auth['input'];

Validator::required($input['id'] ?? null, 'id');
$id = (int) $input['id'];

$deleted = EmployeeAvailabilityModel::deleteRow($id, $tenantId, $employeeId);
if (!$deleted) Response::notFound('Availability row');

AuditLogModel::log($tenantId, null, 'schedule.availability_delete', 'employee_availability', $id);

Response::success(['deleted' => true]);
