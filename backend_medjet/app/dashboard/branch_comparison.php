<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'view_reports');

$branches = BranchModel::getAll($tenantId);
$month = $_GET['month'] ?? date('Y-m');

$comparison = [];
foreach ($branches as $branch) {
    $empCount = BranchModel::getEmployeeCount($branch['id'], $tenantId);
    $todayAtt = AttendanceModel::getByDate($tenantId, date('Y-m-d'), $branch['id']);
    $payroll = PayrollModel::getTotalByMonth($tenantId, $month, $branch['id']);

    $comparison[] = [
        'branch_id' => (int) $branch['id'],
        'branch_name' => $branch['name'],
        'employee_count' => $empCount,
        'today_present' => count(array_filter($todayAtt, fn($a) => $a['status'] === 'present')),
        'payroll' => $payroll ?: [],
    ];
}

Response::success(['comparison' => $comparison, 'month' => $month]);
