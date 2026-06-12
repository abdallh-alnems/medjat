<?php
/**
 * Edit a bulk batch's amount / amount_type / reason and recompute every
 * per-employee row it owns. For percent, each row is re-resolved against the
 * employee's current base_salary.
 *
 * Input: id, amount, amount_type (fixed|percent), reason.
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$id = (int) ($input['id'] ?? 0);
$amount = (float) ($input['amount'] ?? 0);
$amountType = $input['amount_type'] ?? 'fixed';
$reason = trim((string) ($input['reason'] ?? ''));

if ($id <= 0) {
    Response::error('id is required', 422);
}
if (!in_array($amountType, ['fixed', 'percent'], true)) {
    Response::error('Invalid amount_type', 422);
}
if ($amount <= 0) {
    Response::error('Amount must be greater than zero', 422);
}
if ($amountType === 'percent' && $amount > 100) {
    Response::error('Percentage must be between 0 and 100', 422);
}

$batch = BulkAdjustmentModel::findById($id, $tenantId);
if (!$batch) {
    Response::notFound('Bulk adjustment');
}

$kind = $batch['kind'];
$isPercent = $amountType === 'percent';
$members = BulkAdjustmentModel::getMembers($id, $kind, $tenantId);

$updated = 0;
foreach ($members as $m) {
    $rowId = (int) $m['id'];

    if ($isPercent) {
        $empAmount = round(((float) $m['base_salary']) * $amount / 100, 2);
    } else {
        $empAmount = $amount;
    }
    if ($empAmount <= 0) {
        continue;
    }

    $lineReason = $isPercent
        ? $reason . ' (' . rtrim(rtrim(number_format($amount, 2, '.', ''), '0'), '.') . '% من الأساسي)'
        : $reason;

    BulkAdjustmentModel::updateMemberAmount($rowId, $kind, $tenantId, $empAmount, $lineReason);
    $updated++;
}

BulkAdjustmentModel::updateMeta($id, $tenantId, $amount, $amountType, $reason);

AuditLogModel::log($tenantId, $auth['admin_id'], $kind . '.bulk_update', 'bulk_adjustment', $id, [
    'amount' => $amount,
    'amount_type' => $amountType,
    'updated' => $updated,
]);

PayrollCache::invalidate($tenantId);

Response::success(['updated' => $updated, 'message' => 'Bulk adjustment updated']);
