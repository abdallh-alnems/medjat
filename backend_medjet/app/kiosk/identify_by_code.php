<?php
/**
 * Identify an employee by their personal code — the fallback path.
 *
 * Exists because a face will not resolve on some days: a mask, a bandage, a
 * burned-out light above the tablet. Without it one bad morning sends the whole
 * branch back to a supervisor typing punches by hand.
 *
 * It is deliberately weaker than the face path and is treated as such: the
 * resulting log row and attendance record both carry `method = 'code'`, so a
 * code-identified punch is always distinguishable in reporting. A code can be
 * handed to a colleague, and buddy punching is the abuse this whole feature
 * resists — which is why FR-042 forbids a company from running on codes alone.
 *
 * Returns the same envelope as identify.php, including a `punch_ticket`, so the
 * tablet's confirm step is identical either way.
 *
 * Input: code
 */
require_once __DIR__ . '/../../config/bootstrap.php';
require_once __DIR__ . '/../../core/KioskEmployeeCode.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$kiosk = Auth::authenticateKiosk(db());

$tenantId  = $kiosk['tenant_id'];
$branchId  = $kiosk['branch_id'];
$stationId = $kiosk['station_id'];

$branch = BranchModel::findById($branchId, $tenantId);
if (!$branch || empty($branch['station_enabled'])) {
    Response::fail(I18n::t('kiosk_pair_branch_disabled'), 403, 'kiosk_pair_branch_disabled');
}

if (empty($branch['station_code_fallback_enabled'])) {
    Response::fail(I18n::t('kiosk_code_disabled'), 422, 'kiosk_code_disabled');
}

$log = static function (string $result, ?int $employeeId = null, bool $accepted = false) use (
    $tenantId, $stationId, $branchId
): void {
    StationRecognitionLogModel::record([
        'tenant_id'   => $tenantId,
        'station_id'  => $stationId,
        'branch_id'   => $branchId,
        'employee_id' => $employeeId,
        'purpose'     => 'check_in',
        'method'      => 'code',
        'result'      => $result,
        'accepted'    => $accepted,
    ]);
};

// ---- Throttle ---------------------------------------------------------------
// Per station, not per IP: every tablet at a company may share one NAT address,
// so an IP limit would let one abused kiosk lock out every other branch.
$throttleKey = 'kiosk_code_' . $stationId;
if (!RateLimiter::checkLimit($throttleKey, 10, 300)) {
    $log('no_match');

    // A person cannot type ten wrong six-digit codes in five minutes by
    // accident, so this is recorded as a security event rather than a mistake.
    Database::execute(
        "INSERT INTO attendance_security_logs (tenant_id, employee_id, branch_id, reason, action, ip_address)
         SELECT ?, id, ?, 'kiosk_pin_bruteforce', 'blocked', ?
           FROM employees WHERE tenant_id = ? AND branch_id = ? LIMIT 1",
        [$tenantId, $branchId, $_SERVER['REMOTE_ADDR'] ?? null, $tenantId, $branchId]
    );

    Response::fail(I18n::t('kiosk_code_throttled'), 429, 'kiosk_code_throttled');
}

$code = trim((string) ($kiosk['input']['code'] ?? ''));
Validator::required($code, 'code');

$employee = KioskEmployeeCode::resolve($code, $tenantId, $branchId);

if (!$employee) {
    $log('no_match');
    Response::success([
        'outcome'     => 'no_match',
        'message_key' => 'kiosk_code_invalid',
        'code_fallback_available' => true,
    ]);
}

$employeeId = (int) $employee['id'];

// The code identified them, but the same gates as the face path still apply.
$full = EmployeeModel::findById($employeeId, $tenantId);
$methods = AttendanceMethodResolver::resolveForEmployee($full, $tenantId);
if (!in_array('kiosk', $methods, true)) {
    $log('wrong_method', $employeeId);
    Response::success([
        'outcome'     => 'wrong_method',
        'message_key' => 'kiosk_wrong_method',
        'code_fallback_available' => true,
    ]);
}

$today = TenantClock::now($tenantId)->format('Y-m-d');
$existing = Database::fetchOne(
    "SELECT id, check_in_time, check_out_time FROM attendance
      WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
    [$employeeId, $today, $tenantId]
);

$nextAction = (!$existing || empty($existing['check_in_time'])) ? 'check_in' : 'check_out';

if ($nextAction === 'check_out' && !empty($existing['check_out_time'])) {
    $log('too_soon', $employeeId);
    Response::success([
        'outcome'     => 'too_soon',
        'message_key' => 'kiosk_too_soon',
        'code_fallback_available' => true,
    ]);
}

// Same short-lived ticket the face path issues, so punch.php has one contract.
$ticket = bin2hex(random_bytes(32));
Database::execute(
    "INSERT INTO face_challenges (tenant_id, employee_id, nonce, challenge, purpose, expires_at)
     VALUES (?, ?, ?, 'blink', 'check_in', DATE_ADD(NOW(), INTERVAL 30 SECOND))",
    [$tenantId, $employeeId, $ticket]
);

$logId = StationRecognitionLogModel::record([
    'tenant_id'   => $tenantId,
    'station_id'  => $stationId,
    'branch_id'   => $branchId,
    'employee_id' => $employeeId,
    'purpose'     => 'check_in',
    'method'      => 'code',
    'result'      => 'matched',
    'accepted'    => true,
]);

Response::success([
    'outcome'  => 'matched',
    'method'   => 'code',
    'recognition_log_id' => $logId,
    'employee' => [
        'id'        => $employeeId,
        'name'      => $employee['name'],
        'photo_url' => $employee['face_photo_url'] ?? null,
    ],
    'next_action'   => $nextAction,
    'current_state' => ['checked_in_at' => $existing['check_in_time'] ?? null],
    'punch_ticket'  => $ticket,
    'ticket_expires_in_seconds' => 30,
]);
