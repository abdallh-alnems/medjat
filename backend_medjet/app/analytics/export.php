<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'view_analytics');

$dataset = $_GET['dataset'] ?? null;
Validator::required($dataset, 'dataset');
Validator::enum($dataset, ['turnover', 'headcount', 'absence', 'labor_cost'], 'dataset');

$startDate = $_GET['start_date'] ?? date('Y-m-01', strtotime('-11 months'));
$endDate = $_GET['end_date'] ?? date('Y-m-d');
$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;
$department = $_GET['department'] ?? null;

if ($branchId) {
    PermissionMiddleware::checkBranchAccess($auth, $branchId);
}

if ($auth['role'] === 'branch_manager' && !empty($auth['branch_id']) && !$branchId) {
    $branchId = (int) $auth['branch_id'];
}

$dept = $department !== '' ? $department : null;

$headers = [];
$rows = [];

switch ($dataset) {
    case 'turnover':
        $data = AnalyticsModel::turnover($tenantId, $startDate, $endDate, $branchId, $dept);
        $headers = ['Month', 'Headcount Start', 'Headcount End', 'Hires', 'Terminations', 'Turnover Rate %'];
        foreach ($data['series'] as $s) {
            $rows[] = [
                $s['month'], $s['headcount_start'], $s['headcount_end'],
                $s['hires'], $s['terminations'], $s['turnover_rate'],
            ];
        }
        break;

    case 'headcount':
        $data = AnalyticsModel::headcountSeries($tenantId, $startDate, $endDate, $branchId, $dept);
        $headers = ['Month', 'Headcount'];
        foreach ($data['series'] as $s) {
            $rows[] = [$s['month'], $s['headcount']];
        }
        break;

    case 'absence':
        $data = AnalyticsModel::absenceTrend($tenantId, $startDate, $endDate, $branchId, $dept);
        $headers = ['Month', 'Absent Days', 'Present Days', 'Absence Rate %'];
        foreach ($data['series'] as $s) {
            $rows[] = [$s['month'], $s['absent_days'], $s['present_days'], $s['absence_rate']];
        }
        break;

    case 'labor_cost':
        $startMonth = $_GET['start_month'] ?? date('Y-m', strtotime('-11 months'));
        $endMonth = $_GET['end_month'] ?? date('Y-m');
        $includeDraft = isset($_GET['include_draft']) && in_array(strtolower($_GET['include_draft']), ['1', 'true'], true);
        $data = AnalyticsModel::laborCost($tenantId, $startMonth, $endMonth, $branchId, $dept, $includeDraft);
        $headers = ['Month', 'Employees', 'Net Salary', 'Bonuses', 'Deductions', 'Overtime (min)', 'Avg Cost/Employee'];
        foreach ($data['series'] as $s) {
            $rows[] = [
                $s['month'], $s['employee_count'], $s['total_net_salary'],
                $s['total_bonuses'], $s['total_deductions'],
                $s['total_overtime_minutes'], $s['avg_cost_per_employee'],
            ];
        }
        $startDate = $startMonth;
        $endDate = $endMonth;
        break;
}

$filename = "analytics_{$dataset}_{$startDate}_{$endDate}.csv";

header('Content-Type: text/csv; charset=utf-8');
header("Content-Disposition: attachment; filename=\"{$filename}\"");

echo "\xEF\xBB\xBF";

$out = fopen('php://output', 'w');
fputcsv($out, $headers);
foreach ($rows as $r) {
    fputcsv($out, $r);
}
fclose($out);

try {
    AuditLogModel::log($tenantId, $auth['admin_id'], 'analytics.export', null, null, [
        'dataset' => $dataset,
        'start_date' => $startDate,
        'end_date' => $endDate,
    ]);
} catch (Exception $e) {
    error_log("Audit log failed: " . $e->getMessage());
}

exit;
