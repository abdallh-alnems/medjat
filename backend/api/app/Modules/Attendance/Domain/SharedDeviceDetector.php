<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Domain;

use App\Shared\Security\AttendanceSecurityLog;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;

/**
 * Notices when one browser records attendance for more than one employee.
 *
 * This is the realistic abuse of the web channel: an employee hands their PIN to
 * a colleague, who punches for them from their own phone. No non-biometric
 * control can *prevent* that — a willing accomplice defeats possession of a
 * device, knowledge of a PIN, a printed badge and a geofence equally. What can
 * be done is make the pattern visible.
 *
 * So this flags; it never blocks. A wrongly-flagged pair costs a manager a
 * glance; a wrongly-blocked employee loses a day's pay, and the system has no
 * grounds to be that confident.
 */
final class SharedDeviceDetector
{
    /**
     * Other employees who recorded attendance from this browser today.
     *
     * The day boundary is the company's, not the server's — a company in another
     * zone would otherwise have its evening punches compared against the wrong
     * day.
     *
     * @return list<int> Employee ids, excluding the one currently punching.
     */
    public static function otherEmployeesOnDevice(
        int $tenantId,
        string $deviceId,
        int $currentEmployeeId,
        string $tenantDate,
    ): array {
        if ($deviceId === '') {
            return [];
        }

        $rows = DB::table('attendance as a')
            ->join('employee_auth_tokens as t', function (JoinClause $join): void {
                $join->on('t.employee_id', '=', 'a.employee_id')
                    ->on('t.tenant_id', '=', 'a.tenant_id')
                    ->where('t.platform', '=', 'web');
            })
            ->where('a.tenant_id', $tenantId)
            ->where('a.date', $tenantDate)
            ->where('t.device_id', $deviceId)
            ->where('a.employee_id', '!=', $currentEmployeeId)
            ->where(function (QueryBuilder $query): void {
                $query->where('a.check_in_origin', 'web')->orWhere('a.check_out_origin', 'web');
            })
            ->distinct()
            ->pluck('a.employee_id');

        return array_values(array_map(static fn (mixed $id): int => Value::int($id), $rows->all()));
    }

    /**
     * Flags every punch involved, then records the observation.
     *
     * Both sides are flagged, not only the employee who arrived second. A flag
     * on the later punch alone would read as an accusation of one party, when
     * the evidence — one device, two employees — says nothing about which of
     * them lent what to whom.
     *
     * @param  list<int>  $otherEmployeeIds
     */
    public static function flag(
        int $tenantId,
        string $tenantDate,
        int $currentEmployeeId,
        array $otherEmployeeIds,
        ?int $branchId,
    ): void {
        if ($otherEmployeeIds === []) {
            return;
        }

        $ids = array_merge([$currentEmployeeId], $otherEmployeeIds);

        DB::table('attendance')
            ->where('tenant_id', $tenantId)
            ->where('date', $tenantDate)
            ->whereIn('employee_id', $ids)
            ->update(['shared_device_flag' => 1]);

        // 'flagged', never 'blocked' — the observation must not read as a
        // refusal in the security log, because nothing was refused.
        foreach ($ids as $employeeId) {
            AttendanceSecurityLog::record($tenantId, $employeeId, $branchId, 'web_shared_device', 'flagged');
        }
    }
}
