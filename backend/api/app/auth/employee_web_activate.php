<?php

/**
 * First-ever browser sign-in: exchange the single-use activation code for a PIN.
 *
 * The activation code is spent here and never needed again. That is the whole
 * point — a browser session ends at check-out, so the employee needs something
 * they can reuse tomorrow, and the code cannot serve: it is consumed on first
 * use and lapses after 24 hours.
 *
 * Contract: specs/004-web-attendance-checkin/contracts/employee-web-auth.md
 */

require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$phone = trim((string) ($input['phone'] ?? ''));
$code = strtoupper(trim((string) ($input['activation_code'] ?? '')));
$pin = (string) ($input['pin'] ?? '');
$deviceId = trim((string) ($input['device_id'] ?? ''));

if ($phone === '' || $code === '' || $pin === '' || $deviceId === '') {
    Response::fail(I18n::t('missing_fields'), 422, 'missing_fields');
}

// Keyed on the phone as well as the IP. An attacker who spreads attempts across
// addresses would sail past an IP-only limit, and this endpoint is now reachable
// by anyone with the link — which the app's login never really was.
if (!RateLimiter::checkLimit('web_activate:' . preg_replace('/\D/', '', $phone), 10, 3600)) {
    Response::rateLimited(3600);
}

$codeRow = ActivationCodeModel::findByCode($code);
if (!$codeRow) {
    Response::fail(I18n::t('web_invalid_credentials'), 401, 'invalid_activation');
}

$employee = Database::fetchOne(
    "SELECT e.*, b.name AS branch_name, t.name AS tenant_name
     FROM employees e
     LEFT JOIN branches b ON b.id = e.branch_id
     LEFT JOIN tenants  t ON t.id = e.tenant_id
     WHERE e.id = ? AND e.tenant_id = ? LIMIT 1",
    [(int) $codeRow['employee_id'], (int) $codeRow['tenant_id']]
);

if (!$employee) {
    Response::fail(I18n::t('web_invalid_credentials'), 401, 'invalid_activation');
}

if (($employee['status'] ?? '') === 'terminated') {
    Response::fail(I18n::t('account_suspended'), 403, 'account_suspended');
}

if (!EmployeeAccountProvisioner::phoneMatches($phone, $employee['phone'] ?? null)) {
    Response::fail(I18n::t('web_invalid_credentials'), 401, 'invalid_activation');
}

$tenantId = (int) $employee['tenant_id'];
$employeeId = (int) $employee['id'];

// Checked before the code is consumed. Burning an activation code for a company
// that does not allow the channel would leave the employee unable to activate on
// their phone either.
$access = WebAccessPolicy::check($employee, $tenantId);
if (!$access['allowed']) {
    WebAccessPolicy::refuse($tenantId, $employeeId, $access['reason'], null);
}

// Now that the employee is known, the PIN can also be checked against their
// phone number — which is their username here, so a PIN drawn from it is
// guessable by anyone able to attack the account at all.
$pinReject = EmployeeWebCredentialModel::rejectReason($pin, $employee['phone'] ?? null);
if ($pinReject !== null) {
    Response::fail(I18n::t('web_pin_reject_' . $pinReject), 422, 'invalid_pin_format');
}

if (EmployeeWebCredentialModel::findByEmployee($employeeId, $tenantId) !== null) {
    Response::fail(I18n::t('web_already_activated'), 409, 'already_activated');
}

$pdo = db();
$session = null;

try {
    $pdo->beginTransaction();

    EmployeeAccountProvisioner::activate($employee);
    EmployeeWebCredentialModel::set($tenantId, $employeeId, $pin);
    ActivationCodeModel::markUsedByDevice((int) $codeRow['id'], $deviceId);

    // Issued inside the transaction with the credential: a consumed code that
    // produced no credential would strand the employee with nothing to sign in
    // with and no way to get another code except through their administrator.
    $session = WebSessionService::issue($tenantId, $employeeId, $deviceId);

    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log('Employee web activation failed: ' . $e->getMessage());
    Response::fail(I18n::t('generic_error'), 500, 'activation_failed');
}

// Best-effort, and outside the transaction: a failed notification must never
// undo a successful activation.
try {
    EmployeeActivationAlert::notify($employee, true);
} catch (Throwable $e) {
    error_log('Web activation alert failed: ' . $e->getMessage());
}

Response::success([
    'token' => $session['token'],
    'expires_at' => $session['expires_at'],
    'employee' => [
        'id' => $employeeId,
        'name' => $employee['name'],
        'branch_id' => $employee['branch_id'] ? (int) $employee['branch_id'] : null,
        'branch_name' => $employee['branch_name'],
        'tenant_name' => $employee['tenant_name'],
    ],
]);
