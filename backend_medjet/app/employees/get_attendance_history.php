<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_attendance');

$employeeId = (int) ($_GET['employee_id'] ?? 0);
if ($employeeId <= 0) {
    Response::fail('Employee ID required', 422);
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
        Response::fail('Invalid month format (expected YYYY-MM)', 422);
    }
    $from = $month . '-01';
    $to   = date('Y-m-t', strtotime($from));
}

if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $from) ||
    !preg_match('/^\d{4}-\d{2}-\d{2}$/', $to)) {
    Response::fail('Invalid date format (expected YYYY-MM-DD)', 422);
}

if (strtotime($from) > strtotime($to)) {
    Response::fail('Start date must be on or before end date', 422);
}

// Safety cap so a careless range can't fetch years of rows.
$daySpan = (strtotime($to) - strtotime($from)) / 86400;
if ($daySpan > 366) {
    Response::fail('Date range cannot exceed 366 days', 422);
}

$rows = Database::fetchAll(
    "SELECT
        a.id,
        a.employee_id,
        DATE_FORMAT(a.date, '%Y-%m-%d') AS date,
        CASE WHEN a.check_in_time IS NOT NULL
             THEN CONCAT(DATE_FORMAT(a.date, '%Y-%m-%d'), 'T', a.check_in_time)
        END AS check_in,
        CASE WHEN a.check_out_time IS NOT NULL
             THEN CONCAT(DATE_FORMAT(a.date, '%Y-%m-%d'), 'T', a.check_out_time)
        END AS check_out,
        a.status,
        a.late_minutes,
        a.overtime_minutes,
        a.worked_minutes,
        a.notes AS note,
        a.deduction_mode,
        a.deduction_value,
        l.type AS leave_type
     FROM attendance a
     LEFT JOIN leaves l
            ON l.employee_id = a.employee_id
           AND l.tenant_id = a.tenant_id
           AND l.date = a.date
           AND l.start_date = l.end_date
           AND l.status = 'approved'
     WHERE a.employee_id = ?
       AND a.tenant_id = ?
       AND a.date BETWEEN ? AND ?
     ORDER BY a.date DESC",
    [$employeeId, $tenantId, $from, $to]
);

$summary = [
    'present' => 0,
    'absent'  => 0,
    'late'    => 0,
    'leave'   => 0,
    'holiday' => 0,
    'weekly_off' => 0,
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
