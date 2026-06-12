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

Response::success([
    'records' => $records,
    'month' => $month,
    'employee_id' => (int) $employee['id'],
    'attendance_config' => $attendanceConfig,
]);
