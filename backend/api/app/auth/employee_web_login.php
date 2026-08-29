<?php

/**
 * Everyday browser sign-in: phone + the PIN set at activation.
 *
 * Contract: specs/004-web-attendance-checkin/contracts/employee-web-auth.md
 */

require_once __DIR__ . '/../../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$phone = trim((string) ($input['phone'] ?? ''));
$pin = (string) ($input['pin'] ?? '');
$deviceId = trim((string) ($input['device_id'] ?? ''));

if ($phone === '' || $pin === '' || $deviceId === '') {
    Response::fail(I18n::t('missing_fields'), 422, 'missing_fields');
}

// Per-phone as well as per-IP. Rate limiting only slows guessing; the real bound
// on a 6-digit space is the lockout below.
$phoneKey = 'web_login:' . preg_replace('/\D/', '', $phone);
if (!RateLimiter::checkLimit($phoneKey, 20, 900)) {
    Response::rateLimited(900);
}

$employee = EmployeeAccountProvisioner::findByPhone($phone);

// One response for "no such phone" and for "wrong PIN". Distinguishing them
// would turn this endpoint into an oracle for which numbers are enrolled, which
// is worth more to an attacker than the PIN itself.
$genericFailure = static function (): void {
    Response::fail(I18n::t('web_invalid_credentials'), 401, 'invalid_credentials');
};

if (!$employee) {
    $genericFailure();
}

$tenantId = (int) $employee['tenant_id'];
$employeeId = (int) $employee['id'];

if (($employee['status'] ?? '') === 'terminated') {
    Response::fail(I18n::t('account_suspended'), 403, 'account_suspended');
}

$credential = EmployeeWebCredentialModel::findByEmployee($employeeId, $tenantId);
if (!$credential) {
    // Distinct from invalid_credentials on purpose: telling an employee who has
    // never set a PIN to "check your PIN" sends them in a circle. This leaks
    // only that the number exists, to someone who already guessed it, and the
    // alternative is a support call for every first-time user.
    Response::fail(I18n::t('web_not_activated'), 404, 'not_activated');
}

if (EmployeeWebCredentialModel::isLocked($employeeId)) {
    AttendanceSecurityModel::log($tenantId, $employeeId, null, 'web_pin_locked', 'blocked');
    Response::fail(I18n::t('web_pin_locked'), 423, 'web_pin_locked');
}

if (!EmployeeWebCredentialModel::verifyPin($credential, $pin)) {
    $nowLocked = EmployeeWebCredentialModel::recordFailure($employeeId);
    if ($nowLocked) {
        AttendanceSecurityModel::log($tenantId, $employeeId, null, 'web_pin_locked', 'blocked');
        Response::fail(I18n::t('web_pin_locked'), 423, 'web_pin_locked');
    }
    $genericFailure();
}

// Checked after the PIN, so a refusal cannot be used to enumerate which
// companies have the channel switched on.
$access = WebAccessPolicy::check($employee, $tenantId);
if (!$access['allowed']) {
    WebAccessPolicy::refuse($tenantId, $employeeId, $access['reason'], null);
}

EmployeeWebCredentialModel::recordSuccess($employeeId);
$session = WebSessionService::issue($tenantId, $employeeId, $deviceId);

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
