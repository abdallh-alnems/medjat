<?php
/**
 * Apply a manual bonus OR deduction to every employee inside a scope
 * (branch / shift / category) in one shot — the "bulk adjustment" feature.
 *
 * It fans out: one manual_bonus/manual_deduction row per matching employee,
 * reusing the existing per-employee payroll path so all downstream math,
 * slips and audit stay consistent. New employees joining the scope later are
 * NOT affected (snapshot at apply time) — same semantics as the single-
 * employee manual adjustment.
 *
 * amount_type:
 *   'fixed'   → the same amount is applied to every employee.
 *   'percent' → amount is a percentage (0–100) of each employee's
 *               base_salary, so the actual figure differs per employee.
 *
 * Input: kind (bonus|deduction), scope_type (branch|shift|category),
 *        scope_id, amount, amount_type (fixed|percent), reason.
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];
$kind = $input['kind'] ?? '';
$scopeType = $input['scope_type'] ?? '';
$scopeId = (int) ($input['scope_id'] ?? 0);
$amount = (float) ($input['amount'] ?? 0);
$amountType = $input['amount_type'] ?? 'fixed';
$reason = trim((string) ($input['reason'] ?? ''));

Validator::required($kind, 'kind');
Validator::required($scopeType, 'scope_type');
Validator::required($scopeId, 'scope_id');
Validator::required($amount, 'amount');

if (!in_array($kind, ['bonus', 'deduction'], true)) {
    Response::error('Invalid kind', 422);
}
if (!in_array($scopeType, ['branch', 'shift', 'category'], true)) {
    Response::error('Invalid scope_type', 422);
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

$employees = EmployeeModel::listForScope($scopeType, $scopeId, $tenantId);
if (!$employees) {
    Response::error('No employees match the selected scope', 404);
}

$isBonus = $kind === 'bonus';
$isPercent = $amountType === 'percent';
$title = $isBonus ? 'مكافأة جديدة' : 'خصم جديد';
$count = 0;
$skipped = 0;

foreach ($employees as $emp) {
    $employeeId = (int) $emp['id'];

    // Resolve the actual figure: a flat amount, or a % of this employee's base.
    if ($isPercent) {
        $empAmount = round(((float) $emp['base_salary']) * $amount / 100, 2);
    } else {
        $empAmount = $amount;
    }

    // Skip employees the percentage resolves to nothing for (e.g. base = 0).
    if ($empAmount <= 0) {
        $skipped++;
        continue;
    }

    // Keep the audit trail readable: note the percentage basis in the reason.
    $lineReason = $isPercent
        ? $reason . ' (' . rtrim(rtrim(number_format($amount, 2, '.', ''), '0'), '.') . '% من الأساسي)'
        : $reason;

    if ($isBonus) {
        BonusRuleModel::addManualBonus($employeeId, $tenantId, $empAmount, $lineReason, $auth['admin_id']);
    } else {
        DeductionRuleModel::addManualDeduction($employeeId, $tenantId, $empAmount, $lineReason, $auth['admin_id']);
    }
    $count++;

    // Notify the linked employee account (best-effort).
    if (!empty($emp['admin_id'])) {
        try {
            $body = $isBonus
                ? "تمت إضافة مكافأة بقيمة {$empAmount} لراتبك."
                : "تمت إضافة خصم بقيمة {$empAmount} على راتبك.";
            NotificationService::sendToUser(
                (int) $emp['admin_id'],
                $title,
                $body,
                [
                    'type' => $isBonus ? 'bonus_added' : 'deduction_added',
                    'amount' => $empAmount,
                    'reason' => $lineReason,
                ]
            );
        } catch (Throwable $e) {
            error_log('Notify employee (bulk ' . $kind . '): ' . $e->getMessage());
        }
    }
}

AuditLogModel::log($tenantId, $auth['admin_id'], $kind . '.bulk', $scopeType, $scopeId, [
    'amount' => $amount,
    'amount_type' => $amountType,
    'count' => $count,
    'skipped' => $skipped,
    'scope_type' => $scopeType,
]);

PayrollCache::invalidate($tenantId);

Response::success([
    'count' => $count,
    'skipped' => $skipped,
    'message' => 'Bulk ' . $kind . ' applied to ' . $count . ' employees',
]);
