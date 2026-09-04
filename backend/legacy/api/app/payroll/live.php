<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$month = $_GET['month'] ?? date('Y-m');
$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;
$limit = isset($_GET['limit']) ? max(1, min(500, (int) $_GET['limit'])) : null;
$offset = max(0, (int) ($_GET['offset'] ?? 0));

// File-based cache (90s TTL). Keyed on tenant + month + branch + paging so
// rapid refreshes from the same user don't re-run the calculator N times.
// Skipped automatically for any month other than the current calendar
// month, because past cycles never change while live cycles do.
$cacheFile = null;
$currentYm = date('Y-m');
if ($month !== $currentYm) {
    // No need to cache historical months — they're not on the fast path.
} else {
    $cacheDir = sys_get_temp_dir() . '/permedjat-payroll-cache';
    if (!is_dir($cacheDir)) @mkdir($cacheDir, 0700, true);
    $key = sprintf(
        'live_%d_%s_%s_%s_%d.json',
        $tenantId, $month,
        $branchId === null ? 'all' : "b$branchId",
        $limit === null ? 'full' : "l{$limit}",
        $offset
    );
    $cacheFile = "$cacheDir/$key";
    if (is_file($cacheFile) && (time() - filemtime($cacheFile)) < 90) {
        $cached = @file_get_contents($cacheFile);
        if ($cached !== false) {
            header('X-Cache: HIT');
            header('Content-Type: application/json; charset=utf-8');
            echo $cached;
            exit;
        }
    }
}

$result = PayrollModel::getLiveOverview($tenantId, $month, $branchId, $limit, $offset);
$result['limit'] = $limit;
$result['offset'] = $offset;

// Tenant-default cycle start day + currency, so the client can label /
// position the picker on the cycle that actually contains today and
// render the right currency symbol next to every amount.
$tenantRow = Database::fetchOne(
    "SELECT cycle_start_day, currency FROM tenants WHERE id = ? LIMIT 1",
    [$tenantId]
);
$result['cycle_start_day'] = (int) ($tenantRow['cycle_start_day'] ?? 1);
$result['currency'] = $tenantRow['currency'] ?? 'EGP';

// Earliest hire date among active employees — the client uses it to cap how
// far back the month picker can navigate (no use viewing months that
// preceded everyone's hire). Scoped to the active branch filter so the
// picker matches what the user actually sees.
$minSql = "SELECT MIN(hire_date) AS d FROM employees
           WHERE tenant_id = ? AND status = 'active'
             AND hire_date IS NOT NULL";
$minParams = [$tenantId];
if ($branchId !== null) {
    $minSql .= " AND branch_id = ?";
    $minParams[] = $branchId;
}
$minRow = Database::fetchOne($minSql, $minParams);
$result['min_hire_date'] = $minRow['d'] ?? null;

// Previous-cycle saved totals — fed to the summary card for the delta arrow.
// Only meaningful when payroll was generated for the previous label month;
// otherwise the client just hides the comparison.
$parts = explode('-', $month);
$year = (int) $parts[0];
$mon = (int) $parts[1];
$prevMon = $mon === 1 ? 12 : $mon - 1;
$prevYear = $mon === 1 ? $year - 1 : $year;
$prevMonth = sprintf('%04d-%02d', $prevYear, $prevMon);
$prevSummary = PayrollModel::getReportSummary($tenantId, $prevMonth, $branchId);
if ((int) ($prevSummary['employee_count'] ?? 0) > 0) {
    $result['previous_summary'] = [
        'month' => $prevMonth,
        'employee_count' => (int) ($prevSummary['employee_count'] ?? 0),
        'total_net' => (float) ($prevSummary['total_net'] ?? 0),
        'total_deductions' => (float) ($prevSummary['total_deductions'] ?? 0),
        'total_bonuses' => (float) ($prevSummary['total_bonuses'] ?? 0),
    ];
}

// Persist to cache (best-effort) so the next request within the TTL
// window can short-circuit before re-running the calculator.
if ($cacheFile !== null) {
    @file_put_contents(
        $cacheFile,
        json_encode(['status' => 'success', 'data' => $result], JSON_UNESCAPED_UNICODE),
        LOCK_EX
    );
    header('X-Cache: MISS');
}

Response::success($result);
