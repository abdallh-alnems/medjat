<?php
/**
 * Create a bulk bonus/deduction batch and fan it out to every eligible employee
 * in the selected scope (all / branch / category / shift / a single employee).
 *
 * One bulk_adjustments row is recorded, then one manual_bonus / manual_deduction
 * row per eligible employee is inserted carrying that batch_id — reusing the
 * existing per-employee payroll path so all downstream math, slips and audit
 * stay consistent. Snapshot at apply time: employees joining the scope later are
 * NOT affected. Suspended/terminated employees are excluded (see listForScope).
 *
 * Employees whose payroll for the target month is already approved/paid are
 * SKIPPED (a manual row can't change a frozen slip) and reported as locked.
 *
 * amount_type:
 *   'fixed'   → the same amount is applied to every employee.
 *   'percent' → amount is a percentage (0–100) of each employee's base_salary,
 *               so the actual figure differs per employee.
 *
 * Input: kind (bonus|deduction), scope_type (all|branch|category|shift|employee),
 *        scope_id (omit/0 for "all"), amount, amount_type (fixed|percent), reason,
 *        month (optional 'YYYY-MM', default current month),
 *        dry_run (optional bool — preview counts/warnings without writing).
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
$month = trim((string) ($input['month'] ?? ''));
$dryRun = filter_var($input['dry_run'] ?? false, FILTER_VALIDATE_BOOLEAN);

Validator::required($kind, 'kind');
Validator::required($scopeType, 'scope_type');

if (!in_array($kind, ['bonus', 'deduction'], true)) {
    Response::error('Invalid kind', 422);
}
if (!in_array($scopeType, ['all', 'branch', 'category', 'shift', 'employee'], true)) {
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
if ($scopeType !== 'all' && $scopeId <= 0) {
    Response::error('scope_id is required', 422);
}

// Default to the current month; validate format when supplied.
if ($month === '') {
    $month = date('Y-m');
} elseif (!preg_match('/^\d{4}-\d{2}$/', $month)) {
    Response::error('Invalid month format (expected YYYY-MM)', 422);
}

// Resolve a human-readable label for the scope (snapshot for display).
$scopeName = null;
switch ($scopeType) {
    case 'branch':
        $branch = BranchModel::findById($scopeId, $tenantId);
        if (!$branch) {
            Response::notFound('Branch');
        }
        $scopeName = $branch['name'] ?? null;
        break;
    case 'category':
        $category = EmployeeCategoryModel::findById($scopeId, $tenantId);
        if (!$category) {
            Response::notFound('Category');
        }
        $scopeName = $category['name'] ?? null;
        break;
    case 'shift':
        $shift = ShiftModel::findById($scopeId, $tenantId);
        if (!$shift) {
            Response::notFound('Shift');
        }
        $scopeName = $shift['name'] ?? null;
        break;
    case 'employee':
        $employee = EmployeeModel::findById($scopeId, $tenantId);
        if (!$employee) {
            Response::notFound('Employee');
        }
        $scopeName = $employee['name'] ?? null;
        break;
}

$employees = EmployeeModel::listForScope($scopeType, $scopeId, $tenantId);
if (!$employees) {
    Response::error('No employees match the selected scope', 404);
}

$isBonus = $kind === 'bonus';
$isPercent = $amountType === 'percent';

// Classify the resolved employees: locked (frozen month), zero (percent of a
// zero base), and eligible (will actually receive a row).
$allIds = array_map(static fn($e) => (int) $e['id'], $employees);
$lockedSet = array_flip(PayrollModel::lockedEmployeeIds($tenantId, $month, $allIds));

$lockedCount = 0;
$zeroCount = 0;
$eligible = [];
foreach ($employees as $emp) {
    $employeeId = (int) $emp['id'];
    if (isset($lockedSet[$employeeId])) {
        $lockedCount++;
        continue;
    }
    $empAmount = $isPercent
        ? round(((float) $emp['base_salary']) * $amount / 100, 2)
        : $amount;
    if ($empAmount <= 0) {
        $zeroCount++;
        continue;
    }
    $eligible[] = ['id' => $employeeId, 'admin_id' => $emp['admin_id'], 'amount' => $empAmount];
}

$duplicate = BulkAdjustmentModel::existsSimilar(
    $tenantId,
    $kind,
    $scopeType,
    $scopeType === 'all' ? null : $scopeId,
    $month
);

// Preview only: report counts/warnings so the UI can confirm before applying.
if ($dryRun) {
    Response::success([
        'dry_run' => true,
        'affected_count' => count($employees),
        'eligible_count' => count($eligible),
        'locked_count' => $lockedCount,
        'zero_count' => $zeroCount,
        'duplicate' => $duplicate,
        'month' => $month,
    ]);
}

if (empty($eligible)) {
    Response::error('No eligible employees (all locked or zero base salary)', 409);
}

$batchId = BulkAdjustmentModel::create(
    $tenantId,
    $kind,
    $scopeType,
    $scopeType === 'all' ? null : $scopeId,
    $scopeName,
    $amount,
    $amountType,
    $reason,
    $auth['admin_id'],
    $month
);

// Note the percentage basis in each row's reason for a readable audit trail.
$percentNote = ' (' . rtrim(rtrim(number_format($amount, 2, '.', ''), '0'), '.') . '% من الأساسي)';

$notifyAdminIds = [];
foreach ($eligible as $e) {
    $lineReason = $isPercent ? $reason . $percentNote : $reason;
    if ($isBonus) {
        BonusRuleModel::addManualBonus((int) $e['id'], $tenantId, (float) $e['amount'], $lineReason, $auth['admin_id'], $batchId, $month);
    } else {
        DeductionRuleModel::addManualDeduction((int) $e['id'], $tenantId, (float) $e['amount'], $lineReason, $auth['admin_id'], $batchId, $month);
    }
    if (!empty($e['admin_id'])) {
        $notifyAdminIds[] = (int) $e['admin_id'];
    }
}

// One batched push instead of a per-employee loop. For a fixed amount the
// figure is identical for everyone, so include it; for percent it differs, so
// keep the body generic.
$title = $isBonus ? 'مكافأة جديدة' : 'خصم جديد';
if ($isPercent) {
    $body = $isBonus ? 'تمت إضافة مكافأة على راتبك.' : 'تمت إضافة خصم على راتبك.';
} else {
    $body = $isBonus
        ? "تمت إضافة مكافأة بقيمة {$amount} لراتبك."
        : "تمت إضافة خصم بقيمة {$amount} على راتبك.";
}
try {
    NotificationService::sendToManyAdmins(
        $notifyAdminIds,
        $title,
        $body,
        ['type' => $isBonus ? 'bonus_added' : 'deduction_added', 'month' => $month]
    );
} catch (Throwable $e) {
    error_log('Notify (bulk ' . $kind . '): ' . $e->getMessage());
}

AuditLogModel::log($tenantId, $auth['admin_id'], $kind . '.bulk', 'bulk_adjustment', $batchId, [
    'amount' => $amount,
    'amount_type' => $amountType,
    'count' => count($eligible),
    'locked' => $lockedCount,
    'zero' => $zeroCount,
    'scope_type' => $scopeType,
    'month' => $month,
]);

PayrollCache::invalidate($tenantId);

Response::success([
    'id' => $batchId,
    'count' => count($eligible),
    'locked' => $lockedCount,
    'skipped' => $zeroCount,
    'month' => $month,
    'message' => 'Bulk ' . $kind . ' applied to ' . count($eligible) . ' employees',
]);
