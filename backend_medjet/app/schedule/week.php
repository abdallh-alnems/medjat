<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_company_settings');

$weekStart = $_GET['week_start'] ?? '';
if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $weekStart)) {
    Response::fail('week_start (YYYY-MM-DD) required', 422);
}
$branchId = ($_GET['branch_id'] ?? null) ? (int) $_GET['branch_id'] : null;

// The roster week starts on the company-configured weekday (ISO 1=Mon..7=Sun,
// default 6=Sat). Snap any incoming date back to its week's start so the grid
// always aligns, and expose the current real-world week start to the client.
$tenant = TenantModel::findById($tenantId);
$weekStartDay = (int) ($tenant['week_start_day'] ?? 6);
$weekStartDay = ($weekStartDay >= 1 && $weekStartDay <= 7) ? $weekStartDay : 6;

$snapToWeekStart = static function (string $date) use ($weekStartDay): string {
    $dow = (int) date('N', strtotime($date)); // 1=Mon..7=Sun
    $diff = ($dow - $weekStartDay + 7) % 7;
    return date('Y-m-d', strtotime($date . " -{$diff} days"));
};

$weekStart = $snapToWeekStart($weekStart);
$currentWeekStart = $snapToWeekStart(date('Y-m-d'));

$weekEnd = date('Y-m-d', strtotime($weekStart . ' +6 days'));
$days = [];
for ($i = 0; $i < 7; $i++) {
    $days[] = date('Y-m-d', strtotime($weekStart . " +{$i} days"));
}

Response::success([
    'week_start' => $weekStart,
    'week_end' => $weekEnd,
    'current_week_start' => $currentWeekStart,
    'week_start_day' => $weekStartDay,
    'days' => $days,
    'employees' => EmployeeShiftScheduleModel::getRosterEmployees($tenantId, $branchId),
    'shifts' => ShiftModel::getByTenant($tenantId, $branchId),
    'cells' => EmployeeShiftScheduleModel::getCells($tenantId, $weekStart, $weekEnd, $branchId),
]);
