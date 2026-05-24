<?php
// Daily job: turn "not arrived yet" into a confirmed "absent" for no-shows.
// Schedule it once near the END of the working day (tenant timezone), e.g.
// 23:50 Africa/Cairo:
//   *5 23 * * *  curl -s "https://<host>/app/cron/mark_absent.php?key=<CRON_SECRET>"
// Idempotent: safe to run more than once.
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

$marked = [];
$total = 0;
foreach ($tenants as $tenant) {
    $tenantId = (int) $tenant['id'];
    // Resolve "today" in the tenant's timezone so the day boundary is correct.
    try {
        $now = new DateTime('now', !empty($tenant['timezone'])
            ? new DateTimeZone($tenant['timezone'])
            : null);
    } catch (Exception $e) {
        $now = new DateTime('now');
    }
    $date = $now->format('Y-m-d');

    $count = AttendanceModel::markAbsent($tenantId, $date);
    if ($count > 0) {
        $marked[$tenantId] = $count;
        $total += $count;
    }
}

header('Content-Type: application/json');
echo json_encode([
    'status' => 'success',
    'total_marked' => $total,
    'by_tenant' => $marked,
]);
