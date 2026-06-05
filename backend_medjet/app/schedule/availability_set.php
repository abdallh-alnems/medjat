<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employeeId = $auth['employee_id'];
$input = $auth['input'];

$rows = $input['rows'] ?? [];
if (!is_array($rows)) Response::fail('rows must be an array', 422);

foreach ($rows as $i => $row) {
    if (!isset($row['day_of_week']) || !is_numeric($row['day_of_week'])) {
        Response::fail("rows[{$i}].day_of_week is required (0-6)", 422);
    }
    $dow = (int) $row['day_of_week'];
    if ($dow < 0 || $dow > 6) Response::fail("rows[{$i}].day_of_week must be 0-6", 422);
    if (isset($row['availability'])) {
        Validator::enum($row['availability'], EmployeeAvailabilityModel::LEVELS, "rows[{$i}].availability");
    }
    if (isset($row['start_time']) && $row['start_time'] !== null) {
        Validator::time($row['start_time'], "rows[{$i}].start_time");
    }
    if (isset($row['end_time']) && $row['end_time'] !== null) {
        Validator::time($row['end_time'], "rows[{$i}].end_time");
    }
}

$count = EmployeeAvailabilityModel::replaceWeekly($tenantId, $employeeId, $rows);

AuditLogModel::log($tenantId, null, 'schedule.availability_set', 'employee', $employeeId, ['weekly_rows' => $count]);

Response::success(['saved' => $count]);
