<?php
require_once __DIR__ . '/../../config/bootstrap.php';

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
            'branch_lat' => $geo['lat'],
            'branch_lng' => $geo['lng'],
        ];
    }
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
