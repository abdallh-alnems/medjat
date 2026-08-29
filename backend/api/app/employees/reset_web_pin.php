<?php

/**
 * Administrator reset of an employee's browser PIN.
 *
 * Two jobs in one call. The obvious one is recovery: a 6-digit secret with a
 * 5-attempt lockout will be forgotten and will lock people out, and without a
 * way back the employee simply cannot use the channel again.
 *
 * The less obvious one is control. This is the single call that severs browser
 * access immediately — for a departing employee, a lost laptop, or a PIN that
 * was shared with a colleague. That is why it revokes live sessions rather than
 * letting them run down: a reset that took effect at the next expiry would leave
 * up to sixteen hours of access after the decision to end it.
 */

require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
PermissionMiddleware::check($auth, 'manage_employees');

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$employeeId = (int) ($input['employee_id'] ?? 0);

Validator::required($employeeId, 'employee_id');

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

$pdo = db();
$code = null;

try {
    $pdo->beginTransaction();

    EmployeeWebCredentialModel::clear($employeeId, $tenantId);
    WebSessionService::revokeAllForEmployee($employeeId, 'admin_reset_web_pin');

    // A fresh single-use code, because setting a new PIN goes through the same
    // door as setting the first one. Without it the employee has no way to
    // establish a new secret.
    $code = ActivationCodeModel::generate($tenantId, $employeeId);

    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log('Web PIN reset failed: ' . $e->getMessage());
    Response::fail(I18n::t('generic_error'), 500, 'reset_failed');
}

AuditLogModel::log($tenantId, $auth['admin_id'] ?? null, 'employee.web_pin_reset', 'employee', $employeeId);

Response::success([
    'message' => I18n::t('web_pin_reset_done'),
    'activation_code' => $code['code'] ?? null,
    'expires_at' => $code['expires_at'] ?? null,
]);
