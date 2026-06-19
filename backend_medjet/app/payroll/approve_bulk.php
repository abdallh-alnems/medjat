<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$ids = $input['ids'] ?? [];
if (!is_array($ids) || empty($ids)) {
    Response::fail('ids must be a non-empty array', 422, 'ids_non_empty_array');
}

$touched = PayrollModel::approveMany($ids, $tenantId, $auth['admin_id']);

// Settle loan installments for every approved slip — matches the
// single-row approve.php flow so behavior is consistent.
foreach ($touched as $row) {
    try {
        LoanModel::settleMonth((int) $row['employee_id'], $row['month'], $tenantId);
    } catch (Throwable $e) {
        error_log('Loan settlement (bulk) error: ' . $e->getMessage());
    }
}

AuditLogModel::log(
    $tenantId,
    $auth['admin_id'],
    'payroll.approve.bulk',
    'payroll',
    null,
    ['count' => count($touched), 'ids' => array_map(fn($r) => (int) $r['id'], $touched)]
);

PayrollCache::invalidate($tenantId);

Response::success([
    'approved_count' => count($touched),
    'message' => 'Bulk approval completed',
]);
