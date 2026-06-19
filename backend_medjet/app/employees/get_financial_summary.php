<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$employeeId = (int) ($_GET['employee_id'] ?? 0);
$month = $_GET['month'] ?? date('Y-m');

if ($employeeId <= 0) {
    Response::fail('Employee ID required', 422, 'employee_id_required');
}

if (!preg_match('/^\d{4}-\d{2}$/', $month)) {
    Response::fail('Invalid month format (expected YYYY-MM)', 422, 'invalid_month_format_expected_yyyy');
}

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

// Live calculation respects the company/branch cycle start day and clamps to
// today, so deductions/bonuses/absences only count up to now and the base
// salary is prorated by days elapsed in the cycle.
$breakdown = PayrollCalculator::calculate($employeeId, $month, $tenantId, date('Y-m-d'));

// Effective cycle start day to surface in the response (legacy clients).
$cycleRow = Database::fetchOne(
    "SELECT COALESCE(b.cycle_start_day, t.cycle_start_day, 1) AS d
     FROM tenants t
     LEFT JOIN branches b ON b.id = ? AND b.tenant_id = t.id
     WHERE t.id = ? LIMIT 1",
    [$employee['branch_id'] ?? 0, $tenantId]
);
$cycleStartDay = (int) ($cycleRow['d'] ?? 1);

// Attendance counts for the elapsed part of the cycle, so the financial tab can
// show how the earned amount was reached (present / late / absent / leave days
// + worked / overtime / late minutes). Mirrors the deductions window.
$attFrom = $breakdown['cycle_start'] ?? ($month . '-01');
$attTo = $breakdown['effective_end'] ?? $attFrom;
$attRows = Database::fetchAll(
    "SELECT status, late_minutes, overtime_minutes, worked_minutes
       FROM attendance
      WHERE employee_id = ? AND tenant_id = ? AND date BETWEEN ? AND ?",
    [$employeeId, $tenantId, $attFrom, $attTo]
);
$attendance = [
    'present' => 0, 'late' => 0, 'absent' => 0, 'leave' => 0,
    'holiday' => 0, 'weekly_off' => 0,
    'worked_minutes' => 0, 'overtime_minutes' => 0, 'late_minutes' => 0,
];
foreach ($attRows as $r) {
    switch ($r['status']) {
        case 'present':
            ((int) $r['late_minutes'] > 0) ? $attendance['late']++ : $attendance['present']++;
            break;
        case 'absent':     $attendance['absent']++; break;
        case 'leave':      $attendance['leave']++; break;
        case 'holiday':    $attendance['holiday']++; break;
        case 'weekly_off': $attendance['weekly_off']++; break;
    }
    $attendance['worked_minutes']   += (int) ($r['worked_minutes'] ?? 0);
    $attendance['overtime_minutes'] += (int) ($r['overtime_minutes'] ?? 0);
    $attendance['late_minutes']     += (int) ($r['late_minutes'] ?? 0);
}

// Active deduction & bonus rules, flattened to a key→value map so the
// financial tab can render a transparent "how is this calculated?" card.
$ruleMap = [];
foreach (DeductionRuleModel::getActiveByTenant($tenantId) as $r) {
    $ruleMap[$r['rule_key']] = $r['rule_value'];
}
foreach (BonusRuleModel::getActiveByTenant($tenantId) as $r) {
    $ruleMap[$r['rule_key']] = $r['rule_value'];
}
$rulesPublic = [
    'late_type'                => $ruleMap['late_type'] ?? null,
    'late_unit_minutes'        => isset($ruleMap['late_unit_minutes']) ? (float) $ruleMap['late_unit_minutes'] : null,
    'late_deduction_per_unit'  => isset($ruleMap['late_deduction_per_unit']) ? (float) $ruleMap['late_deduction_per_unit'] : null,
    'late_fixed_amount'        => isset($ruleMap['late_fixed_amount']) ? (float) $ruleMap['late_fixed_amount'] : null,
    'absence_multiplier'       => isset($ruleMap['absence_multiplier']) ? (float) $ruleMap['absence_multiplier'] : null,
    'overtime_multiplier'      => isset($ruleMap['overtime_multiplier']) ? (float) $ruleMap['overtime_multiplier'] : null,
];

// Stored slip row (if generated), for status (draft/approved/paid). Joined
// with admins so the financial tab's "Approved by X" audit line can render
// without a second query.
$slip = Database::fetchOne(
    "SELECT p.*, a.name AS approved_by_name
     FROM payroll p
     LEFT JOIN admins a ON a.id = p.approved_by
     WHERE p.employee_id = ? AND p.month = ? AND p.tenant_id = ? LIMIT 1",
    [$employeeId, $month, $tenantId]
);

// Once a slip is approved/paid it is LOCKED: surface the frozen snapshot
// captured at approval (stored in payroll.breakdown) instead of the live
// recalculation, so what HR sees matches exactly what was approved/paid.
// Drafts (and months with no slip yet) keep showing the live estimate.
$status = $slip['status'] ?? 'draft';
$locked = $slip && in_array($status, ['approved', 'paid'], true);
$frozen = [];
if ($locked && !empty($slip['breakdown'])) {
    $decoded = json_decode($slip['breakdown'], true);
    if (is_array($decoded)) {
        $frozen = $decoded;
    }
}
// Source for the money figures + line-item breakdown: frozen snapshot when
// locked, otherwise the live calculation.
$src = ($locked && $frozen) ? $frozen : $breakdown;

// History of stored slips for this employee (most-recent first).
$history = Database::fetchAll(
    "SELECT id, month, base_salary, total_deductions, total_bonuses,
            net_salary, status, approved_at, paid_at
     FROM payroll
     WHERE employee_id = ? AND tenant_id = ?
     ORDER BY month DESC
     LIMIT 24",
    [$employeeId, $tenantId]
);

Response::success([
    'month'    => $month,
    'employee' => [
        'id'           => (int) $employee['id'],
        'name'         => $employee['name'],
        'base_salary'  => (float) ($employee['base_salary'] ?? 0),
    ],
    'current'  => [
        'base_salary'      => $src['base_salary'] ?? 0,
        'total_deductions' => $src['total_deductions'] ?? 0,
        'total_bonuses'    => $src['total_bonuses'] ?? 0,
        'net_salary'       => $src['net_salary'] ?? 0,
        'deductions'       => $src['deductions_breakdown'] ?? [],
        'bonuses'          => $src['bonuses_breakdown'] ?? [],
        'statutory'        => $src['statutory_breakdown'] ?? null,
        'status'           => $status,
        'locked'           => $locked,
        'payroll_id'       => isset($slip['id']) ? (int) $slip['id'] : null,
        'approved_at'      => $slip['approved_at'] ?? null,
        'approved_by_name' => $slip['approved_by_name'] ?? null,
        'paid_at'          => $slip['paid_at'] ?? null,
        'cycle_start_day'      => $cycleStartDay,
        'cycle_from'           => $src['cycle_start'] ?? null,
        'cycle_to'             => $src['cycle_end'] ?? null,
        'days_in_month'        => $src['days_in_cycle'] ?? 0,
        'days_elapsed'         => $src['days_elapsed'] ?? 0,
        'prorated_base_salary' => $src['prorated_base_salary'] ?? 0,
        'earned_to_date'       => $src['earned_to_date'] ?? 0,
        'attendance'           => $attendance,
        'rules'                => $rulesPublic,
    ],
    'loans'          => LoanModel::getActiveSummaryForEmployee($employeeId, $tenantId),
    'salary_history' => AuditLogModel::getBaseSalaryHistory($employeeId, $tenantId, 20),
    'history'        => $history,
]);
