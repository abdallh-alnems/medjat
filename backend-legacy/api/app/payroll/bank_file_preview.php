<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$month = $_GET['month'] ?? null;
Validator::required($month, 'month');

if (!preg_match('/^\d{4}-\d{2}$/', $month)) {
    Response::fail('Invalid month format. Use YYYY-MM', 400, 'invalid_month_format_yyyy_mm');
}

$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;

$rows = PayrollModel::getApprovedForBankFile($tenantId, $month, $branchId);

$ready = [];
$missing = [];
$totalAmount = 0;

foreach ($rows as $row) {
    if (!empty($row['bank_account_number']) || !empty($row['bank_iban'])) {
        $ready[] = $row;
        $totalAmount += (float) $row['net_salary'];
    } else {
        $missing[] = [
            'id' => $row['employee_id'],
            'name' => $row['employee_name'],
        ];
    }
}

$tenant = TenantModel::findById($tenantId);

Response::success([
    'month' => $month,
    'total_employees' => count($rows),
    'total_amount' => round($totalAmount, 2),
    'ready_count' => count($ready),
    'missing_bank_count' => count($missing),
    'missing' => $missing,
    'available_exporters' => PayrollExporterRegistry::availableFor($tenant),
]);
