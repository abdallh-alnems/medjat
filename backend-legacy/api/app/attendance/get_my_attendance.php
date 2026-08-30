<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];

$month = $_GET['month'] ?? date('Y-m');
$records = AttendanceModel::getByEmployeeMonth($employee['id'], $month, $tenantId);

$branchId = (int) ($employee['branch_id'] ?? 0);
$attendanceConfig = null;
if ($branchId > 0) {
    $branch = BranchModel::findById($branchId, $tenantId);
    if ($branch) {
        // Effective geofence: branch center if set, else the company default.
        $geo = BranchModel::effectiveGeofence($branchId, $tenantId);
        $attendanceConfig = [
            'branch_id' => $branchId,
            'branch_name' => $branch['name'],
            'methods' => AttendanceMethodResolver::resolveForEmployee($employee, $tenantId),
            'gps_radius_meters' => (int) $geo['radius'],
            'allow_offline' => BranchModel::effectiveAllowOffline($branchId, $tenantId),
            // The app needs this to know whether to raise the device-biometric
            // prompt before submitting. The server enforces it regardless; this
            // only stops the employee being rejected after doing the work.
            'require_local_biometric' => TenantModel::requiresLocalBiometric($tenantId),
            'branch_lat' => $geo['lat'],
            'branch_lng' => $geo['lng'],
        ];
    }
}

// Whether to offer the crew screen at all. Answered here, on a call the home
// screen already makes, rather than by having every employee hit crew_list.php
// on launch to be told they supervise nobody — which is true of almost all of
// them. Derived from whether anyone points at this employee, so it cannot
// disagree with what crew_list.php will return.
//
// Only added when there IS a config, so a branchless employee keeps getting a
// null here instead of a half-populated object. That also lines up with what
// crew_check_in.php does: no branch means no geofence to verify against, so it
// refuses anyway — offering the button would be a dead end.
if ($attendanceConfig !== null) {
    $attendanceConfig['is_crew_supervisor'] =
        CrewModel::isSupervisor((int) $employee['id'], $tenantId);
}

// The employee's expected attendance time for today, as configured by
// management. A rotating schedule cell (if published) overrides the default
// shift; a cell with no shift means an explicit rest day.
$today = date('Y-m-d');
$sched = EmployeeShiftScheduleModel::findEffective((int) $employee['id'], $tenantId, $today);
if ($sched !== null) {
    $isRestDay = empty($sched['shift_id']);
    $shiftStart = $isRestDay ? null : ($sched['start_time'] ?? null);
    $shiftEnd = $isRestDay ? null : ($sched['end_time'] ?? null);
    $shiftName = null;
} else {
    $isRestDay = false;
    $shiftStart = $employee['shift_start'] ?? $employee['work_start_time'] ?? null;
    $shiftEnd = $employee['shift_end'] ?? $employee['work_end_time'] ?? null;
    $shiftName = $employee['shift_name'] ?? null;
}

$todayShift = [
    'start_time' => $shiftStart,
    'end_time' => $shiftEnd,
    'shift_name' => $shiftName,
    'is_rest_day' => $isRestDay,
];

Response::success([
    'records' => $records,
    'month' => $month,
    'employee_id' => (int) $employee['id'],
    'attendance_config' => $attendanceConfig,
    'today_shift' => $todayShift,
]);
