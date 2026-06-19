<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_attendance');

$employeeId = (int) ($_GET['employee_id'] ?? 0);
if ($employeeId <= 0) {
    Response::fail('Employee ID required', 422, 'employee_id_required');
}

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

// Accept either:
//   - month=YYYY-MM (legacy / month tab), or
//   - from=YYYY-MM-DD & to=YYYY-MM-DD (custom range)
$from = $_GET['from'] ?? null;
$to   = $_GET['to'] ?? null;
$month = $_GET['month'] ?? null;

if ($from === null || $to === null) {
    $month = $month ?: date('Y-m');
    if (!preg_match('/^\d{4}-\d{2}$/', $month)) {
        Response::fail('Invalid month format (expected YYYY-MM)', 422, 'invalid_month_format_expected_yyyy');
    }
    $from = $month . '-01';
    $to   = date('Y-m-t', strtotime($from));
}

if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $from) ||
    !preg_match('/^\d{4}-\d{2}-\d{2}$/', $to)) {
    Response::fail('Invalid date format (expected YYYY-MM-DD)', 422, 'invalid_date_format_expected_yyyy');
}

if (strtotime($from) > strtotime($to)) {
    Response::fail('Start date must be on or before end date', 422, 'start_date_before_end_date');
}

// Safety cap so a careless range can't fetch years of rows.
$daySpan = (strtotime($to) - strtotime($from)) / 86400;
if ($daySpan > 366) {
    Response::fail('Date range cannot exceed 366 days', 422, 'date_range_cannot_exceed_366');
}

// Tenant timezone drives "today" and the shift-end cutoff used to decide
// between 'absent' and 'not_arrived' for the in-progress day.
$tenant = TenantModel::findById($tenantId);
$tz = $tenant['timezone'] ?? null;

// Persist any pending no-show absences so payroll/reports stay in sync. The
// calendar below would render correct statuses regardless, but materializing
// keeps the rest of the system consistent. Best-effort; never block the view.
try {
    AttendanceModel::catchUpAbsences($tenantId, $tz);
} catch (Throwable $e) {
    error_log('get_attendance_history catchUpAbsences failed: ' . $e->getMessage());
}

// Gap-free calendar: materialized rows + synthesized statuses for missing days
// ('absent' / 'not_arrived' / 'leave' / 'holiday' / 'weekly_off').
$rows = AttendanceModel::getEmployeeAttendanceCalendar($employeeId, $tenantId, $from, $to, $tz);

$summary = [
    'present' => 0,
    'absent'  => 0,
    'late'    => 0,
    'leave'   => 0,
    'holiday' => 0,
    'weekly_off' => 0,
    'not_arrived' => 0,
    'worked_minutes' => 0,
    'overtime_minutes' => 0,
    'late_minutes' => 0,
];

foreach ($rows as $r) {
    if ($r['status'] === 'present') {
        if ((int) $r['late_minutes'] > 0) {
            $summary['late']++;
        } else {
            $summary['present']++;
        }
    } elseif ($r['status'] === 'absent') {
        $summary['absent']++;
    } elseif ($r['status'] === 'leave') {
        $summary['leave']++;
    } elseif ($r['status'] === 'holiday') {
        $summary['holiday']++;
    } elseif ($r['status'] === 'weekly_off') {
        $summary['weekly_off']++;
    } elseif ($r['status'] === 'not_arrived') {
        $summary['not_arrived']++;
    }
    $summary['worked_minutes']  += (int) ($r['worked_minutes'] ?? 0);
    $summary['overtime_minutes'] += (int) ($r['overtime_minutes'] ?? 0);
    $summary['late_minutes']    += (int) ($r['late_minutes'] ?? 0);
}

Response::success([
    'records' => $rows,
    'summary' => $summary,
    'from'    => $from,
    'to'      => $to,
]);
