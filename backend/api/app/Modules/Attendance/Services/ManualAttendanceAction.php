<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Services;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * Attendance recorded *for* an employee by an administrator.
 *
 * Three shapes, because they mean different things. Both times is a whole day
 * being entered after the fact and simply replaces whatever was there. A
 * check-in alone refuses to overwrite an arrival that already exists — that
 * would erase a real punch behind a manager's back. A check-out alone needs an
 * arrival to attach to.
 */
final class ManualAttendanceAction
{
    /**
     * A whole day, entered after the fact.
     */
    public function wholeDay(
        Employee $employee,
        int $branchId,
        int $tenantId,
        string $date,
        string $checkIn,
        string $checkOut,
        int $recordedBy,
    ): void {
        [$start, $end] = $this->shiftWindow($employee, $tenantId, $date);

        DB::table('attendance')->upsert(
            [[
                'tenant_id' => $tenantId,
                'branch_id' => $branchId,
                'employee_id' => $employee->id,
                'date' => $date,
                'check_in_time' => $checkIn,
                'check_out_time' => $checkOut,
                'check_in_method' => 'manual',
                'status' => 'present',
                'recorded_by' => $recordedBy,
                'late_minutes' => $this->minutesBetween($start, $checkIn),
                'worked_minutes' => $this->minutesBetween($checkIn, $checkOut),
                'overtime_minutes' => $this->minutesBetween($end, $checkOut),
            ]],
            ['tenant_id', 'employee_id', 'date'],
            [
                'check_in_time', 'check_out_time', 'check_in_method', 'recorded_by',
                'late_minutes', 'worked_minutes', 'overtime_minutes',
            ],
        );
    }

    /**
     * An arrival on its own.
     *
     * @throws ApiFailure When the day already has one — overwriting it would
     *                    erase a real punch behind the employee's back.
     */
    public function checkInOnly(
        Employee $employee,
        int $branchId,
        int $tenantId,
        string $date,
        string $checkIn,
        int $recordedBy,
    ): void {
        $existing = DB::table('attendance')
            ->where('employee_id', $employee->id)->where('tenant_id', $tenantId)->where('date', $date)
            ->first(['id', 'check_in_time', 'branch_id']);

        if ($existing !== null && Value::string($existing->check_in_time) !== '') {
            throw new ApiFailure(__('messages.checkin_exists_for_date'), 400, 'already_checked_in');
        }

        [$start] = $this->shiftWindow($employee, $tenantId, $date);
        $late = $this->minutesBetween($start, $checkIn);

        if ($existing !== null) {
            DB::table('attendance')->where('id', Value::int($existing->id))->update([
                'check_in_time' => $checkIn,
                'check_in_method' => 'manual',
                'status' => 'present',
                'recorded_by' => $recordedBy,
                'late_minutes' => $late,
                // The existing branch wins; only a row without one takes this.
                'branch_id' => Value::nullableInt($existing->branch_id) ?? $branchId,
            ]);

            return;
        }

        DB::table('attendance')->insert([
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'employee_id' => $employee->id,
            'date' => $date,
            'check_in_time' => $checkIn,
            'check_in_method' => 'manual',
            'status' => 'present',
            'recorded_by' => $recordedBy,
            'late_minutes' => $late,
        ]);
    }

    /**
     * A departure on its own.
     *
     * @throws ApiFailure When there is no arrival to attach it to.
     */
    public function checkOutOnly(
        Employee $employee,
        int $tenantId,
        string $date,
        string $checkOut,
        int $recordedBy,
    ): void {
        $record = DB::table('attendance')
            ->where('employee_id', $employee->id)->where('tenant_id', $tenantId)->where('date', $date)
            ->first(['id', 'check_in_time']);

        if ($record === null || Value::string($record->check_in_time) === '') {
            throw new ApiFailure(__('messages.no_checkin_for_date'), 404, 'no_check_in_record');
        }

        [, $end] = $this->shiftWindow($employee, $tenantId, $date);
        $checkIn = Value::string($record->check_in_time);

        DB::table('attendance')->where('id', Value::int($record->id))->update([
            'check_out_time' => $checkOut,
            'check_out_method' => 'manual',
            'recorded_by' => $recordedBy,
            'worked_minutes' => $this->minutesBetween($checkIn, $checkOut),
            'overtime_minutes' => $this->minutesBetween($end, $checkOut),
        ]);
    }

    public function setNote(int $tenantId, int $attendanceId, ?string $note): void
    {
        DB::table('attendance')->where('id', $attendanceId)->where('tenant_id', $tenantId)
            ->update(['notes' => $this->trimNote($note)]);
    }

    public function setNoteForDay(int $tenantId, int $employeeId, string $date, ?string $note): void
    {
        DB::table('attendance')
            ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)->where('date', $date)
            ->update(['notes' => $this->trimNote($note)]);
    }

    private function trimNote(?string $note): ?string
    {
        if ($note === null) {
            return null;
        }

        $clean = mb_substr(trim($note), 0, 2000);

        return $clean === '' ? null : $clean;
    }

    /**
     * @return array{string, string}
     */
    private function shiftWindow(Employee $employee, int $tenantId, string $date): array
    {
        $shift = DB::table('employee_shift_schedule as ess')
            ->leftJoin('shifts as s', 's.id', '=', 'ess.shift_id')
            ->where('ess.employee_id', $employee->id)
            ->where('ess.tenant_id', $tenantId)
            ->where('ess.work_date', $date)
            ->where('ess.status', 'published')
            ->first(['s.start_time', 's.end_time']);

        return [
            Value::string($shift?->start_time) ?: Value::string($employee->getAttribute('work_start_time'), '09:00:00'),
            Value::string($shift?->end_time) ?: Value::string($employee->getAttribute('work_end_time'), '17:00:00'),
        ];
    }

    private function minutesBetween(string $from, string $to): int
    {
        $fromAt = strtotime($from);
        $toAt = strtotime($to);

        if ($fromAt === false || $toAt === false) {
            return 0;
        }

        return (int) max(0, ($toAt - $fromAt) / 60);
    }
}
