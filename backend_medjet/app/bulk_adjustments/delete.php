<?php
/**
 * Delete a whole bulk batch: removes every per-employee row it created and the
 * batch record itself. Notifies affected employees (best-effort).
 *
 * Input: id.
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$id = (int) ($auth['input']['id'] ?? 0);
if ($id <= 0) {
    Response::error('id is required', 422);
}

$batch = BulkAdjustmentModel::findById($id, $tenantId);
if (!$batch) {
    Response::notFound('Bulk adjustment');
}

$kind = $batch['kind'];
$isBonus = $kind === 'bonus';

// Capture members for notifications before we delete the rows.
$members = BulkAdjustmentModel::getMembers($id, $kind, $tenantId);

BulkAdjustmentModel::deleteBatch($id, $kind, $tenantId);

foreach ($members as $m) {
    if (empty($m['admin_id'])) {
        continue;
    }
    try {
        $title = $isBonus ? 'إلغاء مكافأة' : 'إلغاء خصم';
        $body = $isBonus
            ? "تم إلغاء مكافأة بقيمة {$m['amount']} من راتبك."
            : "تم إلغاء خصم بقيمة {$m['amount']} من راتبك.";
        NotificationService::sendToUser(
            (int) $m['admin_id'],
            $title,
            $body,
            ['type' => $isBonus ? 'bonus_removed' : 'deduction_removed', 'amount' => $m['amount']]
        );
    } catch (Throwable $e) {
        error_log('Notify employee (bulk delete ' . $kind . '): ' . $e->getMessage());
    }
}

AuditLogModel::log($tenantId, $auth['admin_id'], $kind . '.bulk_delete', 'bulk_adjustment', $id, [
    'removed' => count($members),
]);

PayrollCache::invalidate($tenantId);

Response::success(['message' => 'Bulk adjustment deleted']);
