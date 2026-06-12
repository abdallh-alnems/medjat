<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];
$employee = $auth['employee'];

$month = $_GET['month'] ?? date('Y-m');
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
$slip['breakdown'] = $breakdown;
$slip['deductions_breakdown'] = $breakdown['deductions_breakdown'] ?? [];
$slip['bonuses_breakdown'] = $breakdown['bonuses_breakdown'] ?? [];

Response::success($slip);
