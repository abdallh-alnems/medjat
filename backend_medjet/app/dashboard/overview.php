<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;
$totalEmployees = EmployeeModel::countByTenant($tenantId, $branchId);
$totalBranches = TenantModel::getBranchCount($tenantId);
$todayAttendance = AttendanceModel::getByDate($tenantId, date('Y-m-d'), $branchId);
$currentMonth = date('Y-m');
$payrollTotal = PayrollModel::getTotalByMonth($tenantId, $currentMonth, $branchId);

$presentCount = count(array_filter($todayAttendance, fn($a) => $a['status'] === 'present'));
$absentCount = count(array_filter($todayAttendance, fn($a) => $a['status'] === 'absent'));

Response::success([
    'total_employees' => $totalEmployees,
    'total_branches' => $totalBranches,
    'today_attendance' => [
        'present' => $presentCount,
        'absent' => $absentCount,
        'total' => count($todayAttendance),
    ],
    'payroll_summary' => $payrollTotal ?: [
        'employee_count' => 0,
        'total_base' => 0,
        'total_deductions' => 0,
        'total_bonuses' => 0,
        'total_net' => 0,
    ],
    'current_month' => $currentMonth,
]);
