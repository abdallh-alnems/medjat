<?php
// Stream the payroll slip for an employee/month as a PDF download.
// Used by the financial tab's "Download/Share payslip" button. The slip is
// generated on demand from the live PayrollCalculator output (matches what the
// UI shows in the financial tab) and the company branding from the tenant.
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$employeeId = (int) ($_GET['employee_id'] ?? 0);
$month = $_GET['month'] ?? date('Y-m');

if ($employeeId <= 0) {
    Response::fail('Employee ID required', 422);
}
if (!preg_match('/^\d{4}-\d{2}$/', $month)) {
    Response::fail('Invalid month format (expected YYYY-MM)', 422);
}

$employee = Database::fetchOne(
    "SELECT e.*, b.name AS branch_name
     FROM employees e
     LEFT JOIN branches b ON b.id = e.branch_id
     WHERE e.id = ? AND e.tenant_id = ? LIMIT 1",
    [$employeeId, $tenantId]
);
if (!$employee) {
    Response::notFound('Employee');
}

$tenant = TenantModel::findById($tenantId);
if (!$tenant) {
    Response::notFound('Tenant');
}

// Use the same "as-of today" clamp the financial tab uses, so the PDF matches
// what the user sees on screen.
$breakdown = PayrollCalculator::calculate($employeeId, $month, $tenantId, date('Y-m-d'));

try {
    $path = PayslipPdfService::generate($tenant, $employee, $breakdown, $month);
} catch (Throwable $e) {
    error_log('Payslip PDF generation failed: ' . $e->getMessage());
    Response::fail('Failed to generate payslip', 500);
}

$fileName = 'payslip_' . $employeeId . '_' . $month . '.pdf';
header('Content-Type: application/pdf');
header('Content-Disposition: attachment; filename="' . $fileName . '"');
header('Content-Length: ' . filesize($path));
header('Cache-Control: private, no-cache');
readfile($path);
exit;
