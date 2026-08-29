<?php

declare(strict_types=1);

namespace App\Http\Controllers\Attendance;

use App\Domain\Audit\AuditLog;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Services\Attendance\ManualAttendanceAction;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/attendance/update_note.php.
 *
 * Addressable either by attendance id or by employee and date, because the
 * management screen has one and the sheet has the other.
 */
final class UpdateNoteController
{
    public function __construct(private readonly ManualAttendanceAction $manual) {}

    public function __invoke(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $attendanceId = Value::int($request->input('attendance_id'));
        $employeeId = Value::int($request->input('employee_id'));
        $date = Value::string($request->input('date'));

        $note = trim(Value::string($request->input('note')));
        $note = $note === '' ? null : $note;

        // Existence is checked before the write, not inferred from it: MySQL
        // reports zero affected rows when the value is unchanged, which would
        // otherwise make a successful no-op save look like a missing record.
        if ($attendanceId > 0) {
            $exists = DB::table('attendance')->where('id', $attendanceId)->where('tenant_id', $tenantId)->exists();
            if (! $exists) {
                throw new ApiFailure('Attendance record not found', 404, 'attendance_record_not_found');
            }

            $this->manual->setNote($tenantId, $attendanceId, $note);
        } else {
            if ($employeeId <= 0 || preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) !== 1) {
                throw new ApiFailure('employee_id and a valid date are required', 422, 'missing_fields');
            }

            $exists = DB::table('attendance')
                ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)->where('date', $date)
                ->exists();

            if (! $exists) {
                throw new ApiFailure('Attendance record not found', 404, 'attendance_record_not_found');
            }

            $this->manual->setNoteForDay($tenantId, $employeeId, $date, $note);
        }

        AuditLog::record(
            $tenantId,
            $admin->id,
            'attendance.note_updated',
            'attendance',
            $attendanceId > 0 ? $attendanceId : $employeeId,
        );

        return ApiResponse::success(['message' => 'Note updated', 'note' => $note]);
    }
}
