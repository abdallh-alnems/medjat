<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();

PermissionMiddleware::check($auth, 'manage_attendance');

$input = $auth['input'];
$attendanceId = isset($input['attendance_id']) ? (int) $input['attendance_id'] : 0;
$employeeId = isset($input['employee_id']) ? (int) $input['employee_id'] : 0;
$date = $input['date'] ?? null;
$rawNote = $input['note'] ?? '';
$note = trim((string) $rawNote);
$note = $note === '' ? null : $note;

// MySQL's UPDATE rowCount returns 0 when the value is unchanged, which would
// otherwise mask a successful no-op save. Verify the record exists first, then
// update unconditionally.
if ($attendanceId > 0) {
    $exists = Database::fetchOne(
        "SELECT id FROM attendance WHERE id = ? AND tenant_id = ? LIMIT 1",
        [$attendanceId, $tenantId]
    );
    if (!$exists) {
        Response::fail('Attendance record not found', 404, 'attendance_record_not_found');
    }
    AttendanceModel::updateNoteById($tenantId, $attendanceId, $note);
} else {
    Validator::required($employeeId, 'employee_id');
    Validator::date($date, 'date');
    $exists = Database::fetchOne(
        "SELECT id FROM attendance WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
        [$employeeId, $date, $tenantId]
    );
    if (!$exists) {
        Response::fail('Attendance record not found', 404, 'attendance_record_not_found');
    }
    AttendanceModel::updateNote($tenantId, $employeeId, $date, $note);
}

AuditLogModel::log(
    $tenantId,
    $auth['admin_id'],
    'attendance.note_updated',
    'attendance',
    $attendanceId > 0 ? $attendanceId : $employeeId
);

Response::success(['message' => 'Note updated', 'note' => $note]);
