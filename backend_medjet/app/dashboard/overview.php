<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;
$shiftId = ($_GET['shift_id'] ?? null) ? (int) $_GET['shift_id'] : null;
$categoryId = ($_GET['category_id'] ?? null) ? (int) $_GET['category_id'] : null;

// "Today" resolved in the tenant timezone (fallback to server time).
$tenant = TenantModel::findById($tenantId);
$tz = $tenant['timezone'] ?? null;
try {
    $now = new DateTime('now', $tz ? new DateTimeZone($tz) : null);
} catch (Exception $e) {
    $now = new DateTime('now');
}
$today = $now->format('Y-m-d');
$yesterday = (clone $now)->modify('-1 day')->format('Y-m-d');

// Lazily materialize absences on app open (no cron): backfill completed days
// since the last run and confirm today's already-ended shifts, so the board
// below reflects no-shows immediately. Never let a failure break the dashboard.
try {
    AttendanceModel::catchUpAbsences($tenantId, $tz);
} catch (Throwable $e) {
    error_log('catchUpAbsences (overview) failed: ' . $e->getMessage());
}

// Active employees (filtered) joined with today's attendance. Reusing the
// live-board query keeps status derivation identical to the live screen and
// gives us branch/shift/category filtering for free.
$rows = AttendanceModel::getLiveBoard($tenantId, $today, $branchId, $shiftId, $categoryId);

// Two distinct counts:
//  - $totalEmployees: true company headcount (no filters) → drives the
//    first-run empty state ("no employees yet").
//  - $activeInScope: active employees matching the current branch/shift/category
//    filter → the attendance-rate denominator and per-card percentages, so the
//    rate stays correct when a filter is applied.
$totalEmployees = EmployeeModel::countByTenant($tenantId);
$activeInScope = count($rows);
$present = 0;
$absent = 0;
$late = 0;
$onLeave = 0;

// Per-branch aggregation for the "branch performance" / comparison sections.
$branchAgg = [];

foreach ($rows as $row) {
    $checkIn = $row['check_in_time'] ?? null;
    $attStatus = $row['attendance_status'] ?? null;
    $lateMinutes = (int) ($row['late_minutes'] ?? 0);
    $isPresent = (bool) $checkIn; // checked in (in or out)
    $isLate = $lateMinutes > 0 && $isPresent;

    // Derive the day bucket once (one leave lookup per employee, not two).
    // "absent" is now ONLY a confirmed absence (an explicit 'absent' record,
    // written by AttendanceModel::catchUpAbsences — invoked above on every
    // dashboard load and nightly by the catchup_absences cron). Active
    // employees with no record yet are "not arrived" (shown by the live
    // "not in" card), NOT absent — so the two no longer overlap.
    if ($isPresent) {
        $bucket = 'present';
    } elseif (in_array($attStatus, ['leave', 'holiday', 'weekly_off'], true)
        || LeaveModel::isEmployeeOnLeave((int) $row['employee_id'], $today, $tenantId)) {
        $bucket = 'leave';
    } elseif ($attStatus === 'absent') {
        $bucket = 'absent';
    } else {
        $bucket = 'not_in'; // no record yet — hasn't arrived
    }

    if ($bucket === 'present') {
        $present++;
    } elseif ($bucket === 'leave') {
        $onLeave++;
    } elseif ($bucket === 'absent') {
        $absent++;
    }
    if ($isLate) {
        $late++;
    }

    $bId = $row['branch_id'] !== null ? (int) $row['branch_id'] : 0;
    if (!isset($branchAgg[$bId])) {
        $branchAgg[$bId] = [
            'branch_id' => $bId,
            'branch_name' => $row['branch_name'] ?? '',
            'total_employees' => 0,
            'present' => 0,
            'absent' => 0,
            'late' => 0,
        ];
    }
    $branchAgg[$bId]['total_employees']++;
    if ($bucket === 'present') {
        $branchAgg[$bId]['present']++;
    } elseif ($bucket === 'absent') {
        $branchAgg[$bId]['absent']++;
    }
    if ($isLate) {
        $branchAgg[$bId]['late']++;
    }
}

$branchStats = array_values(array_map(function ($b) {
    $total = (int) $b['total_employees'];
    $b['attendance_rate'] = $total > 0 ? round(($b['present'] / $total) * 100, 1) : 0;
    $b['late_rate'] = $total > 0 ? round(($b['late'] / $total) * 100, 1) : 0;
    return $b;
}, $branchAgg));

// Wider context for the comprehensive home view. The action queue and the
// financial summary are intentionally tenant-wide (company level) and ignore
// the branch/shift/category customization, which only scopes today's
// attendance. The app shows a "company-wide" note when a filter is active.
$currentMonth = $now->format('Y-m');
$totalBranches = TenantModel::getBranchCount($tenantId);
$pendingLeaves = LeaveModel::countPending($tenantId);
$payroll = PayrollModel::getTotalByMonth($tenantId, $currentMonth);

// Approval queues + financials for the home action list (tenant-wide).
$pendingLetters = DocumentRequestModel::countPending($tenantId);
$pendingLoans = LoanModel::countPending($tenantId);
$pendingBreaks = BreakRequestModel::countPending($tenantId);
$assetsToReturn = AssetModel::countReturnRequested($tenantId);
$pendingExpenses = ExpenseModel::countPending($tenantId);
$monthlyExpenses = ExpenseModel::totalForMonth($tenantId, $currentMonth);
// Credentials (iqama/passport/work-permit/contract/health) expiring within 30
// days or already expired — surfaced as a compliance alert.
$expiringCompliance = count(EmployeeModel::getExpiringCompliance($tenantId, 30, null, true));
// Yesterday's check-ins, for the attendance-rate trend.
$presentYesterday = AttendanceModel::countPresentOnDate($tenantId, $yesterday, $branchId);

Response::success([
    'total_employees' => $totalEmployees,
    'active_in_scope' => $activeInScope,
    'present_today' => $present,
    'present_yesterday' => $presentYesterday,
    'absent_today' => $absent,
    'late_today' => $late,
    'on_leave_today' => $onLeave,
    'branch_stats' => $branchStats,
    'total_branches' => $totalBranches,
    'pending_leaves' => $pendingLeaves,
    'pending_letters' => $pendingLetters,
    'pending_loans' => $pendingLoans,
    'pending_breaks' => $pendingBreaks,
    'assets_to_return' => $assetsToReturn,
    'pending_expenses' => $pendingExpenses,
    'monthly_expenses' => $monthlyExpenses,
    'expiring_compliance' => $expiringCompliance,
    'payroll_summary' => [
        'employee_count' => (int) ($payroll['employee_count'] ?? 0),
        'total_base' => (float) ($payroll['total_base'] ?? 0),
        'total_deductions' => (float) ($payroll['total_deductions'] ?? 0),
        'total_bonuses' => (float) ($payroll['total_bonuses'] ?? 0),
        'total_net' => (float) ($payroll['total_net'] ?? 0),
    ],
    'current_month' => $currentMonth,
]);
