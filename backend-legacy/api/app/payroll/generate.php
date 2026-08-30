<?php
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$month = $input['month'] ?? date('Y-m');
$branchId = ($input['branch_id'] ?? null) ? (int) $input['branch_id'] : null;

$results = PayrollModel::generate($tenantId, $month, $branchId);

AuditLogModel::log($tenantId, $auth['admin_id'], 'payroll.generate', null, null, ['month' => $month]);

try {
    $recipients = SmartAlertService::recipientsForBranch($tenantId, $branchId, 'manage_payroll');
    foreach ($recipients as $rid) {
        if ($rid === $auth['admin_id']) continue;
        SmartAlertService::dispatch(
            $rid, 'payroll_events', 'payroll',
            'كشف رواتب جديد', "تم توليد كشف رواتب لشهر {$month}",
            'Payroll Generated', "Payroll generated for {$month}",
            ['month' => $month, 'branch_id' => $branchId, 'count' => count($results)],
            "payroll_gen:{$tenantId}:{$month}:" . ($branchId ?? 'all')
        );
    }
} catch (Throwable $e) {
    error_log('SmartAlert payroll generate: ' . $e->getMessage());
}

PayrollCache::invalidate($tenantId);

Response::success([
    'month' => $month,
    'generated_count' => count($results),
]);
