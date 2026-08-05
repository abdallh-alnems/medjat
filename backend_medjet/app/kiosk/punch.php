<?php
/**
 * Record the attendance the employee just confirmed.
 *
 * Redeems the `punch_ticket` issued by identify.php rather than accepting an
 * `employee_id` from the request. Without that, a tablet could identify as one
 * person and punch as another — and unlike every other channel, a kiosk
 * credential would let it do that for anybody in the branch.
 *
 * Writes through the existing AttendanceModel methods, not a parallel INSERT.
 * Those methods compute `late_minutes`, `worked_minutes`, `overtime_minutes`
 * and `status` against the employee's shift and stamp the time via TenantClock;
 * a bespoke insert here would silently diverge from every other channel and
 * show up months later as payroll that does not reconcile.
 *
 * Input: punch_ticket, direction (check_in|check_out), idempotency_key
 */
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$kiosk = Auth::authenticateKiosk(db());

$tenantId  = $kiosk['tenant_id'];
$branchId  = $kiosk['branch_id'];
$stationId = $kiosk['station_id'];
$input     = $kiosk['input'];

$ticket = (string) ($input['punch_ticket'] ?? '');
$idempotencyKey = (string) ($input['idempotency_key'] ?? '');

Validator::required($ticket, 'punch_ticket');
Validator::required($idempotencyKey, 'idempotency_key');

// ---- Idempotency ------------------------------------------------------------
// Checked BEFORE the ticket is consumed. A retry after a lost response arrives
// with the same key and a ticket that was already spent; treating that as an
// error would tell the employee their punch failed when it succeeded.
// Each direction carries its own key: one attendance row holds both a check-in
// and a check-out, so a single column would let the second punch overwrite the
// first one's key and silently void its replay protection.
$already = Database::fetchOne(
    "SELECT id, date, check_in_time, check_out_time, worked_minutes
       FROM attendance
      WHERE tenant_id = ?
        AND (kiosk_checkin_idem_key = ? OR kiosk_checkout_idem_key = ?)
      LIMIT 1",
    [$tenantId, $idempotencyKey, $idempotencyKey]
);

if ($already) {
    Response::success([
        'attendance_id' => (int) $already['id'],
        'replayed'      => true,
        'recorded_at'   => $already['check_out_time'] ?: $already['check_in_time'],
        'worked_minutes'=> $already['worked_minutes'] !== null ? (int) $already['worked_minutes'] : null,
    ]);
}

// ---- Redeem the ticket ------------------------------------------------------
// Single-use, short-lived, and consumed in SQL so two taps cannot both spend it.
$consumed = Database::execute(
    "UPDATE face_challenges SET consumed_at = NOW()
      WHERE nonce = ? AND tenant_id = ? AND consumed_at IS NULL AND expires_at > NOW()",
    [$ticket, $tenantId]
);
if ($consumed === 0) {
    Response::fail(I18n::t('kiosk_no_match'), 410, 'kiosk_ticket_spent');
}

$ticketRow = Database::fetchOne(
    "SELECT employee_id FROM face_challenges WHERE nonce = ? LIMIT 1",
    [$ticket]
);
$employeeId = (int) ($ticketRow['employee_id'] ?? 0);
if ($employeeId <= 0) {
    Response::fail(I18n::t('kiosk_no_match'), 410, 'kiosk_ticket_spent');
}

$employee = EmployeeModel::findById($employeeId, $tenantId);
if (!$employee) {
    Response::notFound('Employee');
}

// The employee must still belong to this kiosk's branch. The ticket is 30
// seconds old, but a transfer in that window must not land a punch on the wrong
// branch's books.
if ((int) ($employee['branch_id'] ?? 0) !== $branchId) {
    Response::fail(I18n::t('kiosk_out_of_branch'), 403, 'kiosk_out_of_branch');
}

$direction = ($input['direction'] ?? 'check_in') === 'check_out' ? 'check_out' : 'check_in';
$today = TenantClock::now($tenantId)->format('Y-m-d');

// ---- How was this person identified? ----------------------------------------
// Read off the recognition log rather than taken from the request. The client
// supplies the row id, but every field that ends up on the attendance record —
// the method and the confidence — comes from what the SERVER wrote at
// identification time. A tablet cannot upgrade a code punch into a face punch by
// asserting it, which matters because face-versus-code is the security boundary
// of the feature.
$recognitionLogId = (int) ($input['recognition_log_id'] ?? 0);
$recognitionMethod = null;
$confidence = null;
$logRow = null;

if ($recognitionLogId > 0) {
    $logRow = Database::fetchOne(
        "SELECT id, method, match_score, employee_id
           FROM station_recognition_logs
          WHERE id = ? AND tenant_id = ? AND station_id = ? AND employee_id = ?
            AND accepted = 1
            AND created_at > DATE_SUB(NOW(), INTERVAL 5 MINUTE)
          LIMIT 1",
        [$recognitionLogId, $tenantId, $stationId, $employeeId]
    );
}

if ($logRow) {
    $recognitionMethod = $logRow['method'] === 'code' ? 'station_code' : 'station_face';
    $confidence = $logRow['match_score'] !== null ? (float) $logRow['match_score'] : null;
} else {
    // No verifiable log row: record the punch, but do not claim a recognition
    // method it cannot substantiate. A NULL here is honest; 'station_face'
    // would be evidence that does not exist.
    $recognitionMethod = null;
}

// ---- Write ------------------------------------------------------------------
if ($direction === 'check_in') {
    $attendanceId = AttendanceModel::checkIn(
        $employeeId,
        $branchId,
        $tenantId,
        'kiosk',                 // check_in_method — already a valid enum value
        null,                    // time: let the model stamp it via TenantClock
        null,
        null,
        false,
        $recognitionMethod,      // station_face | station_code | null
        $confidence
    );
} else {
    AttendanceModel::checkOut($employeeId, $tenantId);

    $row = Database::fetchOne(
        "SELECT id FROM attendance WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
        [$employeeId, $today, $tenantId]
    );
    $attendanceId = (int) ($row['id'] ?? 0);

    Database::execute(
        "UPDATE attendance SET check_out_method = 'kiosk' WHERE id = ?",
        [$attendanceId]
    );
}

// Close the loop: the recognition attempt now points at the punch it produced,
// so a disputed row can be traced back to the scores behind it.
if ($logRow && $attendanceId > 0) {
    StationRecognitionLogModel::linkAttendance((int) $logRow['id'], $attendanceId);
}

// Stamp the station and this punch's key on whichever row we just touched.
$keyColumn = $direction === 'check_in' ? 'kiosk_checkin_idem_key' : 'kiosk_checkout_idem_key';
Database::execute(
    "UPDATE attendance
        SET station_id = ?, {$keyColumn} = ?
      WHERE id = ? AND tenant_id = ?",
    [$stationId, $idempotencyKey, $attendanceId, $tenantId]
);

KioskStationModel::recordPunch($stationId);

$final = Database::fetchOne(
    "SELECT check_in_time, check_out_time, worked_minutes, late_minutes
       FROM attendance WHERE id = ? LIMIT 1",
    [$attendanceId]
);

Response::success([
    'attendance_id' => $attendanceId,
    'direction'     => $direction,
    'replayed'      => false,
    'recorded_at'   => $direction === 'check_in'
        ? ($final['check_in_time'] ?? null)
        : ($final['check_out_time'] ?? null),
    'employee' => [
        'id'   => $employeeId,
        'name' => $employee['name'],
    ],
    'worked_minutes' => $final['worked_minutes'] !== null ? (int) $final['worked_minutes'] : null,
    'late_minutes'   => $final['late_minutes'] !== null ? (int) $final['late_minutes'] : null,
]);
