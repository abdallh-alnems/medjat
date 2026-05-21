<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$month = $_GET['month'] ?? null;
Validator::required($month, 'month');

if (!preg_match('/^\d{4}-\d{2}$/', $month)) {
    Response::fail('Invalid month format. Use YYYY-MM', 400);
}

$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;
$format = $_GET['format'] ?? 'csv';

$rows = PayrollModel::getApprovedForBankFile($tenantId, $month, $branchId);

$ready = [];
$missing = [];
foreach ($rows as $row) {
    if (!empty($row['bank_account_number']) || !empty($row['bank_iban'])) {
        $ready[] = $row;
    } else {
        $missing[] = [
            'id' => $row['employee_id'],
            'name' => $row['employee_name'],
        ];
    }
}

$tenant = TenantModel::findById($tenantId);
$currency = 'EGP';

$bom = "\xEF\xBB\xBF";
$filename = "payroll_bank_{$month}.csv";

header('Content-Type: text/csv; charset=utf-8');
header("Content-Disposition: attachment; filename=\"{$filename}\"");

$output = fopen('php://output', 'w');
fputs($output, $bom);

fputcsv($output, [
    'الاسم',
    'اسم البنك',
    'رقم الحساب',
    'IBAN',
    'المبلغ الصافي',
    'العملة',
    'الشهر',
]);

foreach ($ready as $row) {
    fputcsv($output, [
        $row['employee_name'],
        $row['bank_name'] ?? '',
        $row['bank_account_number'] ?? '',
        $row['bank_iban'] ?? '',
        number_format((float) $row['net_salary'], 2, '.', ''),
        $currency,
        $month,
    ]);
}

fclose($output);

try {
    AuditLogModel::log($tenantId, $auth['admin_id'], 'payroll.export_bank_file', null, null, ['month' => $month]);
} catch (Exception $e) {
    error_log("Audit log failed: " . $e->getMessage());
}

exit;
