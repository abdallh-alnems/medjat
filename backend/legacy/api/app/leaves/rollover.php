<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_leaves');

$input = $auth['input'];
$fromYear = (int) ($input['from_year'] ?? 0);
Validator::required($fromYear, 'from_year');

if ($fromYear < 2000 || $fromYear > 2100) {
    Response::fail('from_year must be a valid year', 422, 'from_year_valid_year');
}

// Manual trigger from the dashboard. Scheduling (cron) can be added later if needed.
$result = LeaveModel::rolloverYear($tenantId, $fromYear);

AuditLogModel::log($tenantId, $auth['admin_id'], 'leave.rollover', 'tenant', $tenantId, $result);

Response::success([
    'message' => 'Leave balances rolled over',
    'from_year' => $result['from_year'],
    'to_year' => $result['to_year'],
    'processed' => $result['processed'],
    'total_carried' => $result['total_carried'],
    'total_encashed' => $result['total_encashed'],
    'total_dropped' => $result['total_dropped'],
]);
