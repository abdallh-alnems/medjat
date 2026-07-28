<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];

$month = $_GET['month'] ?? date('Y-m');

// The employee app's "download payslip" button asks for the same slip as a
// printable PDF (format=pdf). Without this the endpoint always answered JSON,
// which the app then saved under a .pdf name — producing a file no PDF reader
// could open.
$wantsPdf = strtolower((string) ($_GET['format'] ?? '')) === 'pdf';

/**
 * Renders the employee's own payslip with the shared PayslipPdfService and
 * streams it back. Terminates the request.
 */
function streamOwnPayslipPdf(int $tenantId, array $employee, array $breakdown, string $month): never {
    $tenant = TenantModel::findById($tenantId);
    if (!$tenant) {
        Response::notFound('Tenant');
    }

    try {
        $path = PayslipPdfService::generate($tenant, $employee, $breakdown, $month);
    } catch (Throwable $e) {
        error_log('Employee payslip PDF generation failed: ' . $e->getMessage());
        Response::fail('Failed to generate payslip', 500, 'failed_generate_payslip');
    }

    $fileName = 'payslip_' . (int) $employee['id'] . '_' . $month . '.pdf';
    header('Content-Type: application/pdf');
    header('Content-Disposition: attachment; filename="' . $fileName . '"');
    header('Content-Length: ' . filesize($path));
    header('Cache-Control: private, no-cache');
    header('X-Content-Type-Options: nosniff');
    readfile($path);
    exit;
}

$slip = PayrollModel::getSlip($employee['id'], $month, $tenantId);

if (!$slip) {
    // No saved slip yet — the admin hasn't generated/approved payroll for this
    // month. Instead of an error, show the employee a live preview computed
    // from attendance, loans, deductions and bonuses up to today, flagged as
    // not-yet-paid so they always see their salary breakdown.
    $live = PayrollCalculator::calculate(
        (int) $employee['id'], $month, $tenantId, date('Y-m-d')
    );
    if (empty($live)) {
        Response::notFound('Payroll slip');
    }

    if ($wantsPdf) {
        streamOwnPayslipPdf($tenantId, $employee, $live, $month);
    }

    $live['status'] = 'live';
    $live['deductions_breakdown'] = $live['deductions_breakdown'] ?? [];
    $live['bonuses_breakdown'] = $live['bonuses_breakdown'] ?? [];
    Response::success($live);
}

// `breakdown` is stored as a JSON string (the full PayrollCalculator output).
// Decode it and surface the per-line detail so the employee app can show
// *every* deduction and addition by name and amount, not just the totals.
$breakdown = null;
if (!empty($slip['breakdown'])) {
    $decoded = json_decode($slip['breakdown'], true);
    if (is_array($decoded)) {
        $breakdown = $decoded;
    }
}

if ($wantsPdf) {
    // Print the frozen figures stored on the slip so the PDF matches what was
    // approved/paid. Older slips saved without a breakdown fall back to a live
    // calculation, which is what the financial tab shows for them anyway.
    $figures = $breakdown ?: PayrollCalculator::calculate(
        (int) $employee['id'], $month, $tenantId, date('Y-m-d')
    );
    if (empty($figures)) {
        Response::notFound('Payroll slip');
    }
    streamOwnPayslipPdf($tenantId, $employee, $figures, $month);
}

$slip['breakdown'] = $breakdown;
$slip['deductions_breakdown'] = $breakdown['deductions_breakdown'] ?? [];
$slip['bonuses_breakdown'] = $breakdown['bonuses_breakdown'] ?? [];

Response::success($slip);
