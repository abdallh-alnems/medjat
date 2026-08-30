<?php

declare(strict_types=1);

namespace App\Services\Leave;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Services\Attendance\SetDayStatusAction;
use App\Support\Value;
use DateTimeImmutable;
use Illuminate\Support\Facades\DB;

/**
 * Turning leave that was taken into absence that was not agreed.
 *
 * Every day in the range becomes an absence — which makes it deductible — and
 * then the leave row is deleted rather than marked. Keeping it would leave the
 * days counted against the annual balance as well as charged as absences, so
 * the employee would pay for them twice.
 */
final class ConvertToAbsenceAction
{
    public function __construct(private readonly SetDayStatusAction $setDayStatus) {}

    /**
     * @return array{employee_id: int, days: int}
     */
    public function execute(int $leaveId, int $tenantId, int $adminId, ?string $reason = null): array
    {
        $leave = DB::table('leaves')
            ->where('id', $leaveId)->where('tenant_id', $tenantId)
            ->first([
                'id', 'employee_id',
                DB::raw("DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date"),
                DB::raw("DATE_FORMAT(end_date, '%Y-%m-%d') AS end_date"),
            ]);

        if ($leave === null) {
            throw new ApiFailure('Leave not found', 404, 'not_found');
        }

        $employeeId = Value::int($leave->employee_id);
        $employee = Employee::query()->where('id', $employeeId)->where('tenant_id', $tenantId)->first();

        if ($employee === null) {
            throw new ApiFailure('Employee not found', 404, 'not_found');
        }

        $cursor = new DateTimeImmutable(Value::string($leave->start_date));
        $end = new DateTimeImmutable(Value::string($leave->end_date));
        $note = $reason ?? 'Converted from leave';
        $days = 0;

        while ($cursor <= $end) {
            $this->setDayStatus->execute(
                $employee, $tenantId, $cursor->format('Y-m-d'), 'absent',
                null, null, null, $note, $adminId,
            );
            $days++;
            $cursor = $cursor->modify('+1 day');
        }

        DB::table('leaves')->where('id', $leaveId)->where('tenant_id', $tenantId)->delete();

        return ['employee_id' => $employeeId, 'days' => $days];
    }
}
