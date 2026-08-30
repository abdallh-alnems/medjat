<?php

declare(strict_types=1);

namespace App\Http\Controllers\Schedule;

use App\Domain\Audit\AuditLog;
use App\Domain\Schedule\WeeklyRoster;
use App\Domain\Shifts\Shifts;
use App\Domain\Time\TenantClock;
use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Ports of api/app/schedule/*.php.
 *
 * The rotating-shift grid: who is on which shift on which day, drafted a week
 * at a time and published when the manager is ready to be held to it.
 */
final class RosterController
{
    /** The grid for one week, with everything needed to render it. */
    public function week(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $branchId = self::branchId($request->query('branch_id'));

        $weekStartDay = WeeklyRoster::weekStartDay($tenantId);

        // Snapped rather than rejected: the client may send any day inside the
        // week the user is looking at, and the grid has to line up regardless.
        $weekStart = WeeklyRoster::snapToWeekStart(self::date($request->query('week_start')), $weekStartDay);

        return ApiResponse::success([
            'week_start' => $weekStart,
            'week_end' => WeeklyRoster::weekEnd($weekStart),
            'current_week_start' => WeeklyRoster::snapToWeekStart(
                TenantClock::date($tenantId), $weekStartDay,
            ),
            'week_start_day' => $weekStartDay,
            'days' => WeeklyRoster::days($weekStart),
            'employees' => WeeklyRoster::employees($tenantId, $branchId),
            'shifts' => Shifts::forTenant($tenantId, $branchId),
            'cells' => WeeklyRoster::cells(
                $tenantId, $weekStart, WeeklyRoster::weekEnd($weekStart), $branchId,
            ),
        ]);
    }

    public function assign(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);

        $employeeIds = self::ids($request->input('employee_ids'));
        $dates = self::dates($request->input('dates'));

        if ($employeeIds === [] || $dates === []) {
            throw new ApiFailure(
                'employee_ids and dates arrays are required',
                422,
                'employee_ids_dates_arrays_required',
            );
        }

        // Absent or null means a rest day, which is a decision — distinct from
        // an empty cell, where nothing has been decided.
        $shiftId = $request->input('shift_id') === null ? null : Value::int($request->input('shift_id'));

        if ($shiftId !== null && Shifts::find($shiftId, $tenantId) === null) {
            throw new ApiFailure('Shift not found', 404, 'not_found');
        }

        $count = WeeklyRoster::assign($tenantId, $employeeIds, $dates, $shiftId, $admin->id);

        AuditLog::record($tenantId, $admin->id, 'schedule.assign', 'schedule', null, [
            'cells' => $count,
            'shift_id' => $shiftId,
        ]);

        return ApiResponse::success(['updated' => $count]);
    }

    public function clear(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);

        $employeeId = Value::int($request->input('employee_id'));
        $workDate = Value::string($request->input('work_date'));

        if ($employeeId <= 0 || preg_match('/^\d{4}-\d{2}-\d{2}$/', $workDate) !== 1) {
            throw new ApiFailure(
                'employee_id and work_date (YYYY-MM-DD) required',
                422,
                'employee_id_work_date_yyyy',
            );
        }

        WeeklyRoster::clear($tenantId, $employeeId, $workDate);

        AuditLog::record($tenantId, $admin->id, 'schedule.clear', 'schedule', $employeeId, [
            'work_date' => $workDate,
        ]);

        return ApiResponse::success(['message' => 'Cleared']);
    }

    /** The "copy last week" button, which is how most weeks are built. */
    public function copyWeek(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);

        $from = self::weekStart($request->input('from_week_start'), 'from_week_start');
        $to = self::weekStart($request->input('to_week_start'), 'to_week_start');

        $count = WeeklyRoster::copyWeek(
            $tenantId, $from, $to, self::branchId($request->input('branch_id')), $admin->id,
        );

        AuditLog::record($tenantId, $admin->id, 'schedule.copy_week', 'schedule', null, [
            'from' => $from,
            'to' => $to,
            'cells' => $count,
        ]);

        return ApiResponse::success(['copied' => $count]);
    }

    public function publish(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = self::admin($request);

        $weekStart = self::weekStart($request->input('week_start'), 'week_start');

        $count = WeeklyRoster::publishWeek(
            $tenantId, $weekStart, self::branchId($request->input('branch_id')),
        );

        AuditLog::record($tenantId, $admin->id, 'schedule.publish', 'schedule', null, [
            'week_start' => $weekStart,
            'cells' => $count,
        ]);

        return ApiResponse::success(['published' => $count]);
    }

    private static function weekStart(mixed $raw, string $field): string
    {
        $date = Value::string($raw);

        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) !== 1) {
            throw new ApiFailure(
                $field.' (YYYY-MM-DD) required',
                422,
                'week_start_yyyy_mm_dd',
            );
        }

        return $date;
    }

    private static function date(mixed $raw): string
    {
        $date = Value::string($raw);

        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) !== 1) {
            throw new ApiFailure('week_start (YYYY-MM-DD) required', 422, 'week_start_yyyy_mm_dd');
        }

        return $date;
    }

    /**
     * @return list<int>
     */
    private static function ids(mixed $raw): array
    {
        if (! is_array($raw)) {
            return [];
        }

        return array_values(array_filter(
            array_map(static fn (mixed $id): int => Value::int($id), $raw),
            static fn (int $id): bool => $id > 0,
        ));
    }

    /**
     * @return list<string>
     */
    private static function dates(mixed $raw): array
    {
        if (! is_array($raw)) {
            return [];
        }

        $dates = [];

        foreach ($raw as $date) {
            if (! is_string($date) || preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) !== 1) {
                throw new ApiFailure(
                    'dates must be YYYY-MM-DD strings',
                    422,
                    'dates_yyyy_mm_dd_strings',
                );
            }

            $dates[] = $date;
        }

        return $dates;
    }

    private static function branchId(mixed $raw): ?int
    {
        $branchId = Value::int($raw);

        return $branchId > 0 ? $branchId : null;
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        return $admin;
    }
}
