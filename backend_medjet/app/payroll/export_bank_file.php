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
$exporterKey = $_GET['exporter'] ?? null;

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
$currency = $tenant['currency'] ?? 'EGP';

$exporter = PayrollExporterRegistry::resolve($exporterKey, $tenant);
if ($exporter === null) {
    Response::fail('No payroll exporter available for this country/format', 422);
}

$ext = $exporter->fileExtension();
$filename = "payroll_{$exporter->key()}_{$month}.{$ext}";

header('Content-Type: ' . $exporter->mimeType());
header("Content-Disposition: attachment; filename=\"{$filename}\"");

$out = fopen('php://output', 'w');
$exporter->write($out, new PayrollExportContext($ready, $tenant, $month, $currency));
fclose($out);

try {
    AuditLogModel::log($tenantId, $auth['admin_id'], 'payroll.export_bank_file', null, null, [
        'month' => $month,
        'exporter' => $exporter->key(),
        'country' => $tenant['country_code'] ?? null,
    ]);
} catch (Exception $e) {
    error_log("Audit log failed: " . $e->getMessage());
}

exit;
