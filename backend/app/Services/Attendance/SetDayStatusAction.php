<?php

declare(strict_types=1);

namespace App\Services\Attendance;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Support\Value;
use Illuminate\Support\Facades\DB;
use stdClass;

/**
 * A manager setting what a day *was*, after the fact.
 *
 * The delicate part is that two tables have to agree. A day marked as leave must
 * also exist in the leaves table or the balance silently stops matching what the
 * attendance sheet says; a day moved back off leave must release the day it was
 * holding. Both directions are covered here rather than left to whoever
 * remembers, and both happen in one transaction, because a half-applied change
 * is worse than either state.
 */
final class SetDayStatusAction
{
    /** @var list<string> */
    public const STATUSES = ['present', 'absent', 'leave', 'holiday', 'weekly_off'];

    /** @var list<string> */
    public const LEAVE_TYPES = ['annual', 'sick', 'personal', 'unpaid'];

    /** @var list<string> */
    public const DEDUCTION_MODES = ['auto', 'days', 'amount'];

    /**
     * @return array{record: array<string, mixed>, previous_status: string|null}
     *
     * @throws ApiFailure
     */
    public function execute(
        Employee $employee,
        int $tenantId,
        string $date,
        string $status,
        ?string $checkIn,
        ?string $checkOut,
        ?string $leaveType,
        ?string $reason,
        int $recordedBy,
        string $deductionMode = 'auto',
        ?float $deductionValue = null,
    ): array {
        // A deduction override is meaningful only for an absence; anything else
        // resets it rather than carrying a stale number forward.
        if ($status !== 'absent' || $deductionMode === 'auto') {
            $deductionMode = $status === 'absent' ? $deductionMode : 'auto';
            $deductionValue = null;
        }

        /** @var object{id: int, branch_id: int|null, status: string}|null $existing */
        $existing = DB::table('attendance')
            ->where('employee_id', $employee->id)
            ->where('tenant_id', $tenantId)
            ->where('date', $date)
            ->first(['id', 'branch_id', 'status']);

        $wasLeave = $existing !== null && $existing->status === 'leave';
        $branchId = Value::nullableInt($existing?->branch_id) ?? $employee->branch_id;

        // Times only mean anything on a day somebody was present.
        [$checkInValue, $checkOutValue, $minutes] = $status === 'present'
            ? $this->presentDay($employee, $tenantId, $date, $checkIn, $checkOut)
            : [null, null, ['late' => 0, 'worked' => 0, 'overtime' => 0]];

        $attendanceId = DB::transaction(function () use (
            $employee, $tenantId, $date, $status, $checkInValue, $checkOutValue,
            $minutes, $reason, $recordedBy, $deductionMode, $deductionValue,
            $existing, $branchId, $wasLeave, $leaveType
        ): int {
            $id = $this->writeDay(
                $employee, $tenantId, $date, $status, $checkInValue, $checkOutValue,
                $minutes, $reason, $recordedBy, $deductionMode, $deductionValue,
                $existing, $branchId
            );

            $this->syncLeave($employee->id, $tenantId, $date, $status, $wasLeave, $leaveType, $reason, $recordedBy);

            return $id;
        });

        /** @var array<string, mixed> $record */
        $record = (array) (DB::table('attendance')->where('id', $attendanceId)->first([
            'id', 'employee_id',
            DB::raw("DATE_FORMAT(date, '%Y-%m-%d') as date"),
            'status', 'check_in_time', 'check_out_time',
            'late_minutes', 'worked_minutes', 'overtime_minutes', 'notes',
            'deduction_mode', 'deduction_value',
        ]) ?? new stdClass);

        return [
            'record' => $record,
            'previous_status' => Value::nullableString($existing?->status),
        ];
    }

    /**
     * @return array{string|null, string|null, array{late: int, worked: int, overtime: int}}
     */
    private function presentDay(Employee $employee, int $tenantId, string $date, ?string $checkIn, ?string $checkOut): array
    {
        $shift = DB::table('employee_shift_schedule as ess')
            ->leftJoin('shifts as s', 's.id', '=', 'ess.shift_id')
            ->where('ess.employee_id', $employee->id)
            ->where('ess.tenant_id', $tenantId)
            ->where('ess.work_date', $date)
            ->where('ess.status', 'published')
            ->first(['s.start_time', 's.end_time']);

        $start = Value::string($shift?->start_time) ?: Value::string($employee->getAttribute('work_start_time'), '09:00:00');
        $end = Value::string($shift?->end_time) ?: Value::string($employee->getAttribute('work_end_time'), '17:00:00');

        $minutes = ['late' => 0, 'worked' => 0, 'overtime' => 0];

        if ($checkIn !== null) {
            $minutes['late'] = $this->minutesBetween($start, $checkIn);
        }
        if ($checkIn !== null && $checkOut !== null) {
            $minutes['worked'] = $this->minutesBetween($checkIn, $checkOut);
        }
        if ($checkOut !== null) {
            $minutes['overtime'] = $this->minutesBetween($end, $checkOut);
        }

        return [$checkIn, $checkOut, $minutes];
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

    /**
     * @param  array{late: int, worked: int, overtime: int}  $minutes
     * @param  object{id: int, branch_id: int|null, status: string}|null  $existing
     */
    private function writeDay(
        Employee $employee,
        int $tenantId,
        string $date,
        string $status,
        ?string $checkIn,
        ?string $checkOut,
        array $minutes,
        ?string $reason,
        int $recordedBy,
        string $deductionMode,
        ?float $deductionValue,
        ?object $existing,
        ?int $branchId,
    ): int {
        $values = [
            'status' => $status,
            'check_in_time' => $checkIn,
            'check_out_time' => $checkOut,
            'check_in_method' => 'manual',
            'check_out_method' => $checkOut === null ? null : 'manual',
            'late_minutes' => $minutes['late'],
            'worked_minutes' => $minutes['worked'],
            'overtime_minutes' => $minutes['overtime'],
            'early_leave_minutes' => 0,
            'notes' => $reason,
            'recorded_by' => $recordedBy,
            'deduction_mode' => $deductionMode,
            'deduction_value' => $deductionValue,
        ];

        if ($existing !== null) {
            $id = Value::int($existing->id);

            // The existing branch wins: a row already carries the branch the
            // punch was actually recorded at, and only a row without one takes
            // the employee's posting as a fallback.
            DB::table('attendance')->where('id', $id)->update($values + [
                'branch_id' => Value::nullableInt($existing->branch_id) ?? $branchId,
            ]);

            return $id;
        }

        if ($branchId === null) {
            throw new ApiFailure('Employee has no branch — cannot create an attendance record', 422);
        }

        return (int) DB::table('attendance')->insertGetId($values + [
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'employee_id' => $employee->id,
            'date' => $date,
        ]);
    }

    /**
     * Keeps the leaves table in step so the balance matches the sheet in both
     * directions.
     */
    private function syncLeave(
        int $employeeId,
        int $tenantId,
        string $date,
        string $status,
        bool $wasLeave,
        ?string $leaveType,
        ?string $reason,
        int $recordedBy,
    ): void {
        if ($status !== 'leave' && ! $wasLeave) {
            return;
        }

        // Only single-day approved leave is touched. A multi-day request is a
        // separate thing an employee submitted, and editing one day of the sheet
        // must not silently rewrite it.
        DB::table('leaves')
            ->where('employee_id', $employeeId)
            ->where('tenant_id', $tenantId)
            ->where('date', $date)
            ->whereColumn('start_date', 'end_date')
            ->delete();

        if ($status !== 'leave') {
            return;
        }

        DB::table('leaves')->insert([
            'tenant_id' => $tenantId,
            'employee_id' => $employeeId,
            'date' => $date,
            'start_date' => $date,
            'end_date' => $date,
            'type' => $leaveType ?? 'annual',
            'reason' => $reason,
            'status' => 'approved',
            'approved_by' => $recordedBy,
            'approved_at' => DB::raw('NOW()'),
        ]);
    }
}
