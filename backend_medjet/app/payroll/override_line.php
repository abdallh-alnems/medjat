<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_payroll');

$input = $auth['input'];

$employeeId = (int) ($input['employee_id'] ?? 0);
$month = (string) ($input['month'] ?? '');
$kind = (string) ($input['line_kind'] ?? '');
$type = (string) ($input['line_type'] ?? '');
$date = isset($input['line_date']) && $input['line_date'] !== '' ? (string) $input['line_date'] : null;
$desc = (string) ($input['line_desc'] ?? '');
$action = (string) ($input['action'] ?? '');

Validator::required($employeeId, 'employee_id');
if (!preg_match('/^\d{4}-\d{2}$/', $month)) {
    Response::fail('Invalid month format (expected YYYY-MM)', 422, 'invalid_month_format_expected_yyyy');
}
if (!in_array($kind, ['deduction', 'bonus'], true)) {
    Response::fail('line_kind must be deduction or bonus', 422, 'line_kind_deduction_bonus');
}
if ($type === '') {
    Response::fail('line_type is required', 422, 'line_type_required');
}
if (!in_array($action, ['set', 'waive', 'clear'], true)) {
    Response::fail('action must be set, waive or clear', 422, 'action_set_waive_clear');
}
// Manual deductions/bonuses are edited through their own endpoints.
if ($type === 'manual') {
    Response::fail('Manual lines are edited from their own form', 422, 'manual_lines_edited_from_their');
}

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

// A locked slip (approved/paid) is the source of truth and must not be edited
// in place — the admin reverts it to draft first.
$slip = Database::fetchOne(
    "SELECT status FROM payroll WHERE employee_id = ? AND month = ? AND tenant_id = ? LIMIT 1",
    [$employeeId, $month, $tenantId]
);
if ($slip && in_array($slip['status'], ['approved', 'paid'], true)) {
    Response::fail('Slip is locked. Revert it to draft before editing lines.', 409, 'slip_locked_revert_it_draft');
}

if ($action === 'clear') {
    PayrollLineOverrideModel::clear($tenantId, $employeeId, $month, $kind, $type, $date, $desc);
} else {
    $waived = $action === 'waive';
    $amount = null;
    if (!$waived) {
        if (!isset($input['amount']) || !is_numeric($input['amount'])) {
            Response::fail('amount is required when setting a value', 422, 'amount_required_setting_value');
        }
        $amount = (float) $input['amount'];
        if ($amount < 0) {
            Response::fail('amount must be zero or positive', 422, 'amount_zero_positive');
        }
    }
    $reason = isset($input['reason']) ? trim((string) $input['reason']) : null;
    PayrollLineOverrideModel::upsert(
        $tenantId, $employeeId, $month, $kind, $type, $date, $desc,
        $waived, $amount, $reason !== '' ? $reason : null, $auth['admin_id']
    );
}

AuditLogModel::log(
    $tenantId,
    $auth['admin_id'],
    'payroll.line_override',
    'employee',
    $employeeId,
    ['month' => $month, 'kind' => $kind, 'type' => $type, 'action' => $action]
);

PayrollCache::invalidate($tenantId);

Response::success(['message' => 'Override saved', 'action' => $action]);
