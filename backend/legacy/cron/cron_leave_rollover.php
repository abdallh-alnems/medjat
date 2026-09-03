<?php
/**
 * Automatic year-end leave rollover.
 *
 * Carries each tenant's remaining annual balances into the new year, applying
 * the resolved carryover policy per employee (cap, expiry, encashment, legal
 * floor). Only runs for tenants with `auto_rollover_enabled = 1`, and only on
 * 1 January unless --force is given. Idempotent: re-running the same year just
 * refreshes the figures (UNIQUE upserts), so a missed day can be re-run safely.
 *
 * Carryover EXPIRY needs no sweep here — LeaveModel::getBalance() drops unused
 * expired days dynamically.
 *
 * Schedule on Hostinger (hPanel → Cron Jobs), daily, e.g. 00:30:
 *   /usr/bin/php /home/USER/domains/permedjatapp.com/.../backend/scripts/cron_leave_rollover.php >> /home/USER/cron_rollover.log 2>&1
 *
 * Manual / testing:
 *   php scripts/cron_leave_rollover.php --force                 # run now for all enabled tenants
 *   php scripts/cron_leave_rollover.php --force --tenant=5      # one tenant
 *   php scripts/cron_leave_rollover.php --date=2027-01-01       # simulate a date
 *   php scripts/cron_leave_rollover.php --force --from-year=2025
 */

require_once __DIR__ . '/../config/bootstrap.php';

$opts = getopt('', ['force', 'tenant::', 'date::', 'from-year::']);
$force = isset($opts['force']);
$onlyTenant = isset($opts['tenant']) && $opts['tenant'] !== '' ? (int) $opts['tenant'] : null;
$today = isset($opts['date']) && $opts['date'] !== '' ? $opts['date'] : date('Y-m-d');

$ts = new DateTime($today);
$isJan1 = $ts->format('m-d') === '01-01';

if (!$isJan1 && !$force) {
    echo "[" . date('c') . "] Not 1 January ($today) and --force not set; nothing to do.\n";
    exit(0);
}

// Default: roll the year that just ended.
$fromYear = isset($opts['from-year']) && $opts['from-year'] !== ''
    ? (int) $opts['from-year']
    : ((int) $ts->format('Y') - 1);

$sql = "SELECT id, name FROM tenants WHERE auto_rollover_enabled = 1";
$params = [];
if ($onlyTenant !== null) {
    $sql .= " AND id = ?";
    $params[] = $onlyTenant;
}
$tenants = Database::fetchAll($sql, $params);

echo "[" . date('c') . "] Auto rollover: from_year=$fromYear, tenants=" . count($tenants) . "\n";

$failures = 0;
foreach ($tenants as $t) {
    $tenantId = (int) $t['id'];
    try {
        $result = LeaveModel::rolloverYear($tenantId, $fromYear);
        AuditLogModel::log($tenantId, null, 'leave.rollover.auto', 'tenant', $tenantId, $result);
        echo "  tenant {$tenantId} ({$t['name']}): processed={$result['processed']}, "
            . "carried={$result['total_carried']}, encashed={$result['total_encashed']}, "
            . "dropped={$result['total_dropped']}\n";
    } catch (Throwable $e) {
        $failures++;
        fwrite(STDERR, "  tenant {$tenantId}: FAILED — {$e->getMessage()}\n");
    }
}

echo "[" . date('c') . "] Done. failures=$failures\n";
exit($failures > 0 ? 1 : 0);
