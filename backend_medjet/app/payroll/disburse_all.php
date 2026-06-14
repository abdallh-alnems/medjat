<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$month = $input['month'] ?? date('Y-m');
$branchId = ($input['branch_id'] ?? null) ? (int) $input['branch_id'] : null;

$paidAt = $input['paid_at'] ?? null;
if ($paidAt !== null && !preg_match('/^\d{4}-\d{2}-\d{2}$/', (string) $paidAt)) {
    Response::fail('paid_at must be YYYY-MM-DD', 422);
}

// Active employees in scope — mirrors generate.php / the live overview so a
// branch filter on the screen pays exactly the rows the user is looking at.
$sql = "SELECT id FROM employees
        WHERE tenant_id = ? AND status = 'active'";
$params = [$tenantId];
if ($branchId !== null) {
    $sql .= " AND branch_id = ?";
    $params[] = $branchId;
}
$employees = Database::fetchAll($sql, $params);

$paidCount = 0;
$alreadyPaid = 0;
$paidEmployeeIds = [];
foreach ($employees as $emp) {
    $res = PayrollModel::disburseEmployee(
        (int) $emp['id'], $month, $tenantId, $auth['admin_id'], $paidAt
    );
    if (($res['result'] ?? '') === 'paid') {
        $paidCount++;
        $paidEmployeeIds[] = (int) $emp['id'];
    } elseif (($res['result'] ?? '') === 'already_paid') {
        $alreadyPaid++;
    }
}

AuditLogModel::log(
    $tenantId,
    $auth['admin_id'],
    'payroll.disburse_all',
    'payroll',
    null,
    [
        'month' => $month,
        'branch_id' => $branchId,
        'paid_count' => $paidCount,
        'already_paid' => $alreadyPaid,
    ]
);

PayrollCache::invalidate($tenantId);

// Notify each freshly-paid employee on their mobile app.
foreach ($paidEmployeeIds as $eid) {
    try {
        $info = Database::fetchOne(
            "SELECT admin_id FROM employees WHERE id = ? AND tenant_id = ? LIMIT 1",
            [$eid, $tenantId]
        );
        if ($info && !empty($info['admin_id'])) {
            NotificationService::sendToUser(
                (int) $info['admin_id'],
                'تم دفع راتبك',
                "تم تأكيد دفع راتب شهر {$month}.",
                ['type' => 'payroll_paid', 'month' => $month]
            );
        }
    } catch (Throwable $e) {
        error_log('Notify employee (disburse_all): ' . $e->getMessage());
    }
}

Response::success([
    'paid_count' => $paidCount,
    'already_paid' => $alreadyPaid,
    'total' => count($employees),
    'message' => 'Payroll disbursed',
]);
