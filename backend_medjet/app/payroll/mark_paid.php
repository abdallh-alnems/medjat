<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];

// Accept either a single id or an `ids` array — keeps the contract simple
// for the single-row action without forcing the client to wrap one id.
if (isset($input['ids']) && is_array($input['ids']) && !empty($input['ids'])) {
    $ids = $input['ids'];
} elseif (isset($input['payroll_id'])) {
    $ids = [(int) $input['payroll_id']];
} else {
    Response::fail('payroll_id or ids required', 422);
}

$paidAt = $input['paid_at'] ?? null;
if ($paidAt !== null && !preg_match('/^\d{4}-\d{2}-\d{2}$/', (string) $paidAt)) {
    Response::fail('paid_at must be YYYY-MM-DD', 422);
}

$touched = PayrollModel::markPaidMany($ids, $tenantId, $paidAt);

AuditLogModel::log(
    $tenantId,
    $auth['admin_id'],
    'payroll.mark_paid',
    'payroll',
    null,
    [
        'count' => count($touched),
        'ids' => array_map(fn($r) => (int) $r['id'], $touched),
        'paid_at' => $paidAt,
    ]
);

PayrollCache::invalidate($tenantId);

// Notify each affected employee on their mobile app that the salary was paid.
foreach ($touched as $row) {
    try {
        $info = Database::fetchOne(
            "SELECT e.admin_id FROM employees e WHERE e.id = ? AND e.tenant_id = ? LIMIT 1",
            [(int) $row['employee_id'], $tenantId]
        );
        if ($info && !empty($info['admin_id'])) {
            NotificationService::sendToUser(
                (int) $info['admin_id'],
                'تم دفع راتبك',
                "تم تأكيد دفع راتب شهر {$row['month']}.",
                ['type' => 'payroll_paid', 'month' => $row['month']]
            );
        }
    } catch (Throwable $e) {
        error_log('Notify employee (paid): ' . $e->getMessage());
    }
}

Response::success([
    'paid_count' => count($touched),
    'message' => 'Slips marked as paid',
]);
