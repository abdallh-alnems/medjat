<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Modules\Attendance\Domain\AbsenceBackfill;
use App\Shared\Http\ApiResponse;
use App\Shared\Http\Middleware\RequireBranchAccess;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Port of api/app/attendance/get_branch_attendance.php.
 *
 * The day's board for a manager.
 */
final class BranchAttendanceController
{
    public function __invoke(Request $request): JsonResponse
    {
        $admin = $request->attributes->get('admin');
        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $date = Value::string($request->query('date'), TenantClock::date($tenantId));
        $branchId = Value::int($request->query('branch_id'));
        $branchId = $branchId > 0 ? $branchId : null;

        if ($branchId !== null) {
            RequireBranchAccess::assert($admin, $branchId);
        }

        // For a day that is already over, fill in the absences lazily. Without
        // it a past day with no check-in keeps reading "not arrived" rather than
        // "absent". Idempotent, so running it on every view is safe.
        if ($date < TenantClock::date($tenantId)) {
            AbsenceBackfill::run($tenantId, $date);
        }

        return ApiResponse::success([
            'records' => $this->board($tenantId, $date, $branchId),
            'date' => $date,
        ]);
    }

    /**
     * Starts from active employees rather than from attendance rows, so someone
     * with no row for the day still appears as "not arrived" instead of being
     * invisible.
     *
     * @return list<array<string, mixed>>
     */
    private function board(int $tenantId, string $date, ?int $branchId): array
    {
        $query = DB::table('employees as e')
            ->leftJoin('attendance as a', function (JoinClause $join) use ($date): void {
                $join->on('a.employee_id', '=', 'e.id')
                    ->on('a.tenant_id', '=', 'e.tenant_id')
                    ->where('a.date', '=', $date);
            })
            ->leftJoin('branches as b', 'b.id', '=', DB::raw('COALESCE(a.branch_id, e.branch_id)'))
            ->leftJoin('employee_shift_schedule as sch', function (JoinClause $join) use ($date): void {
                $join->on('sch.employee_id', '=', 'e.id')
                    ->on('sch.tenant_id', '=', 'e.tenant_id')
                    ->where('sch.work_date', '=', $date);
            })
            ->leftJoin('shifts as ss', 'ss.id', '=', 'sch.shift_id')
            ->leftJoin('shifts as s', 's.id', '=', 'e.shift_id')
            ->where('e.tenant_id', $tenantId)
            ->where('e.status', 'active')
            ->orderBy('e.name');

        if ($branchId !== null) {
            $query->where('e.branch_id', $branchId);
        }

        // The COALESCE default is bound rather than interpolated; addBinding
        // puts it in the select clause, where the placeholder sits.
        $query->addBinding($date, 'select');

        $rows = $query->get([
            'a.id',
            'e.id as employee_id',
            'e.name as employee_name',
            'e.job_title',
            DB::raw('COALESCE(a.date, ?) as date'),
            'a.check_in_time',
            'a.check_out_time',
            DB::raw("COALESCE(a.status, 'not_arrived') as status"),
            'a.late_minutes',
            'a.overtime_minutes',
            'a.notes',
            'a.check_in_origin',
            'a.check_out_origin',
            'a.check_in_photo',
            'a.check_out_photo',
            DB::raw('COALESCE(a.shared_device_flag, 0) as shared_device_flag'),
            'b.name as branch_name',
            DB::raw('COALESCE(ss.name, s.name) as shift_name'),
            DB::raw('COALESCE(ss.start_time, s.start_time, e.work_start_time) as shift_start'),
            DB::raw('COALESCE(ss.end_time, s.end_time, e.work_end_time) as shift_end'),
        ]);

        /** @var list<array<string, mixed>> */
        return array_values(array_map(static function (object $row): array {
            $record = (array) $row;

            // The stored paths never leave the server. A client asks for the
            // image by attendance id, through an endpoint that re-checks
            // permission; handing out the path would invite exactly the
            // direct-URL fetching that uploads/ is now closed to.
            $record['has_check_in_photo'] = ! empty($record['check_in_photo']);
            $record['has_check_out_photo'] = ! empty($record['check_out_photo']);
            unset($record['check_in_photo'], $record['check_out_photo']);

            // Advisory, never a verdict: the flag says one browser recorded
            // attendance for more than one employee today, which is information
            // for a manager rather than a rejection.
            $record['shared_device_flag'] = (bool) ($record['shared_device_flag'] ?? false);

            return $record;
        }, $rows->all()));
    }
}
