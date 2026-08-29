<?php
/**
 * Remove a single employee from a bulk batch: deletes that one per-employee row
 * while leaving the rest of the batch intact. Notifies the employee.
 *
 * Input: id (batch id), row_id (the per-employee manual row id).
 */
require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$batchId = (int) ($input['id'] ?? 0);
$rowId = (int) ($input['row_id'] ?? 0);
if ($batchId <= 0 || $rowId <= 0) {
    Response::error('id and row_id are required', 422);
}

$batch = BulkAdjustmentModel::findById($batchId, $tenantId);
if (!$batch) {
    Response::notFound('Bulk adjustment');
}

$kind = $batch['kind'];
$isBonus = $kind === 'bonus';

$member = BulkAdjustmentModel::findMember($rowId, $batchId, $kind, $tenantId);
if (!$member) {
    Response::notFound('Member');
}

$ok = BulkAdjustmentModel::removeMember($rowId, $batchId, $kind, $tenantId);
if (!$ok) {
    Response::error('Could not remove member', 422);
}

if (!empty($member['admin_id'])) {
    try {
        $title = $isBonus ? 'إلغاء مكافأة' : 'إلغاء خصم';
        $body = $isBonus
            ? "تم إلغاء مكافأة بقيمة {$member['amount']} من راتبك."
            : "تم إلغاء خصم بقيمة {$member['amount']} من راتبك.";
        NotificationService::sendToUser(
            (int) $member['admin_id'],
            $title,
            $body,
            ['type' => $isBonus ? 'bonus_removed' : 'deduction_removed', 'amount' => $member['amount']]
        );
    } catch (Throwable $e) {
        error_log('Notify employee (bulk remove_member ' . $kind . '): ' . $e->getMessage());
    }
}

AuditLogModel::log($tenantId, $auth['admin_id'], $kind . '.bulk_remove_member', 'bulk_adjustment', $batchId, [
    'row_id' => $rowId,
    'employee_id' => $member['employee_id'],
]);

PayrollCache::invalidate($tenantId);

Response::success(['message' => 'Member removed']);
