<?php
// Safety-net cron for the lazy absence catch-up.
//
// The dashboard already calls AttendanceModel::catchUpAbsences on every open,
// so absences self-heal as long as someone uses the app. This cron is the
// fallback for stretches with no traffic: it runs the same function for every
// active tenant so gaps never exceed one day.
//
// Recommended schedule: once daily near the end of working hours in the
// tenant timezone (e.g. 23:50 Africa/Cairo). Idempotent — safe to run more
// than once a day.
//
//   50 23 * * *  curl -s "https://<host>/app/cron/catchup_absences.php?key=<CRON_SECRET>"
//
// Replaces the older /app/cron/mark_absent.php, which is now redundant
// (catchUpAbsences honors more exclusions: rotating-schedule rest days and
// per-employee shift-end times).

require_once __DIR__ . '/../../config/bootstrap.php';

$key = $_GET['key'] ?? '';
$expected = getenv('CRON_SECRET') ?: '';
if ($expected === '' || $key !== $expected) {
    http_response_code(403);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Forbidden']);
    exit;
}

$tenants = Database::fetchAll(
    "SELECT id, timezone FROM tenants WHERE is_active = 1"
);

$report = [];
$totals = ['backfilled_days' => 0, 'backfilled_marked' => 0, 'today_marked' => 0];

foreach ($tenants as $tenant) {
    $tenantId = (int) $tenant['id'];
    $tz = !empty($tenant['timezone']) ? $tenant['timezone'] : null;
    try {
        $r = AttendanceModel::catchUpAbsences($tenantId, $tz);
    } catch (Throwable $e) {
        error_log("catchUpAbsences (cron) failed for tenant {$tenantId}: " . $e->getMessage());
        $report[$tenantId] = ['error' => $e->getMessage()];
        continue;
    }
    $report[$tenantId] = $r;
    $totals['backfilled_days'] += $r['backfilled_days'];
    $totals['backfilled_marked'] += $r['backfilled_marked'];
    $totals['today_marked'] += $r['today_marked'];
}

header('Content-Type: application/json');
echo json_encode([
    'status' => 'success',
    'totals' => $totals,
    'by_tenant' => $report,
]);
