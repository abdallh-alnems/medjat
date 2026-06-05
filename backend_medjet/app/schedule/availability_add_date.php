<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];
$input = $auth['input'];

Validator::required($input['specific_date'] ?? null, 'specific_date');
Validator::date($input['specific_date'], 'specific_date');
Validator::enum($input['availability'] ?? '', EmployeeAvailabilityModel::LEVELS, 'availability');

if (isset($input['start_time']) && $input['start_time'] !== null) {
    Validator::time($input['start_time'], 'start_time');
}
if (isset($input['end_time']) && $input['end_time'] !== null) {
    Validator::time($input['end_time'], 'end_time');
}

$id = EmployeeAvailabilityModel::addDateException($tenantId, $employeeId, $input);

AuditLogModel::log($tenantId, null, 'schedule.availability_add_date', 'employee_availability', $id, [
    'specific_date' => $input['specific_date'],
    'availability' => $input['availability'],
]);

Response::success(['id' => $id]);
