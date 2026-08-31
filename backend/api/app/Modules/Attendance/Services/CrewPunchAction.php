<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Services;

use App\Exceptions\ApiFailure;
use App\Models\Branch;
use App\Models\Employee;
use App\Modules\Attendance\Domain\AttendanceMethod;
use App\Modules\Attendance\Domain\GeofenceCheck;
use App\Modules\Attendance\Domain\PunchPhotoStore;
use App\Shared\Crew\Crew;
use App\Shared\Security\AttendanceSecurityLog;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Database\Eloquent\Builder as EloquentBuilder;
use Illuminate\Support\Facades\DB;

/**
 * A supervisor recording arrival — or departure — for the people on site with
 * them.
 *
 * THIS IS THE ONE PLACE AN EMPLOYEE CREDENTIAL ACTS FOR SOMEBODY ELSE. Every
 * other endpoint authenticating an employee touches only that employee's own
 * rows, and the invariant is worth keeping, which is why this lives apart from
 * the ordinary punch rather than as a branch inside it.
 *
 * The exception is bounded by four things, all enforced here:
 *
 *   1. The supervisor is whoever the token says, never the body.
 *   2. A target is writable only if their crew_supervisor_id IS the supervisor.
 *      There is no separate "supervisor" flag to fall out of step with that.
 *   3. The batch is refused whole if any target fails (2).
 *   4. Every row records who recorded it.
 */
final class CrewPunchAction
{
    /**
     * A foreman's crew is tens of people, not thousands. The cap stops a
     * malformed or hostile body turning one request into an unbounded write.
     */
    private const MAX_BATCH = 200;

    /**
     * @param  array<array-key, mixed>  $input
     * @return array{count: int, recorded: list<int>, skipped: array<int, string>, time: string}
     *
     * @throws ApiFailure
     */
    public function execute(Employee $supervisor, int $tenantId, array $input): array
    {
        $employeeIds = $this->batch($input);
        $isCheckOut = ! empty($input['is_check_out']);

        $latitude = Value::float($input['latitude'] ?? null);
        $longitude = Value::float($input['longitude'] ?? null);

        $this->assertAllAreTheirs($supervisor, $tenantId, $employeeIds, $latitude, $longitude);

        if (! in_array('crew_gps', AttendanceMethod::resolveFor($supervisor, $tenantId), true)) {
            throw new ApiFailure(__('messages.crew_attendance_not_enabled'), 403, 'METHOD_NOT_ALLOWED');
        }

        // One fix, from the supervisor's phone, verified once and written onto
        // every row in the batch. That is the honest shape of the evidence: it
        // says "the person who recorded this was at the site", not "each of
        // these thirty people was individually located".
        if ($latitude === 0.0 && $longitude === 0.0) {
            throw new ApiFailure('Location is required', 400, 'LOCATION_REQUIRED');
        }

        $branchId = $supervisor->branch_id;
        if ($branchId === null) {
            throw new ApiFailure(__('messages.supervisor_without_branch'), 409, 'BRANCH_REQUIRED');
        }

        // Mirrors the ordinary punch: a spoofed location invalidates the
        // geofence, so it is checked before it.
        if (! empty($input['is_mock_location']) && $this->rejectsMockLocation($tenantId)) {
            AttendanceSecurityLog::record($tenantId, $supervisor->id, $branchId, 'mock_location', 'blocked', $latitude, $longitude);
            throw new ApiFailure(__('messages.mock_location_detected'), 403, 'MOCK_LOCATION');
        }

        // Check-out is not geofenced, matching the ordinary departure: a crew
        // that has moved off site by knocking-off time should not be left
        // stranded clocked in.
        if (! $isCheckOut) {
            $branch = Branch::query()->forTenant($tenantId)->whereKey($branchId)->first();
            if ($branch === null) {
                throw new ApiFailure(__('messages.branch_not_found'), 404, 'BRANCH_NOT_FOUND');
            }

            $geofence = GeofenceCheck::evaluate($branch, $latitude, $longitude);
            if (! $geofence->passed) {
                AttendanceSecurityLog::record($tenantId, $supervisor->id, $branchId, 'gps_out_of_range', 'blocked', $latitude, $longitude);
                throw new ApiFailure($geofence->message, 400, $geofence->reason ?? 'GPS_OUT_OF_RANGE');
            }
        }

        // Captured before anything is written, so a company that asked for a
        // photograph never ends up with thirty rows and no picture.
        $photo = null;
        if (Crew::photoRequired($tenantId)) {
            $photo = PunchPhotoStore::store(
                is_string($input['photo_base64'] ?? null) ? $input['photo_base64'] : null,
                $tenantId,
                $supervisor->id,
            );

            if ($photo === null) {
                throw new ApiFailure(__('messages.crew_photo_required'), 422, 'PHOTO_REQUIRED');
            }
        }

        $result = $isCheckOut
            ? $this->recordDepartures($employeeIds, $tenantId, $supervisor->id, $photo)
            : $this->recordArrivals($employeeIds, $branchId, $tenantId, $supervisor->id, $latitude, $longitude, $photo);

        return $result + ['time' => TenantClock::time($tenantId)];
    }

    /**
     * @param  array<array-key, mixed>  $input
     * @return list<int>
     */
    private function batch(array $input): array
    {
        $raw = $input['employee_ids'] ?? null;

        if (! is_array($raw) || $raw === []) {
            throw new ApiFailure('employee_ids is required', 422, 'CREW_EMPTY');
        }

        if (count($raw) > self::MAX_BATCH) {
            throw new ApiFailure(__('messages.batch_too_many_employees'), 422, 'CREW_TOO_LARGE');
        }

        $ids = array_values(array_unique(array_filter(
            array_map(static fn (mixed $id): int => Value::int($id), $raw),
            static fn (int $id): bool => $id > 0,
        )));

        if ($ids === []) {
            throw new ApiFailure('employee_ids is required', 422, 'CREW_EMPTY');
        }

        return $ids;
    }

    /**
     * Whole-batch refusal, not silent filtering.
     *
     * A supervisor who sends a name that is no longer theirs has a stale list,
     * and quietly recording the other twenty-nine would leave them believing all
     * thirty were marked. Telling them costs one retry; the silent version costs
     * somebody a day's pay.
     *
     * @param  list<int>  $employeeIds
     */
    private function assertAllAreTheirs(Employee $supervisor, int $tenantId, array $employeeIds, float $lat, float $lng): void
    {
        $theirs = Employee::query()
            ->whereIn('id', $employeeIds)
            ->where('tenant_id', $tenantId)
            ->where('crew_supervisor_id', $supervisor->id)
            ->where(function (EloquentBuilder $query): void {
                $query->whereNull('status')->orWhere('status', '!=', 'terminated');
            })
            ->pluck('id')
            ->all();

        $outsiders = array_values(array_diff($employeeIds, array_map(static fn (mixed $id): int => Value::int($id), $theirs)));

        if ($outsiders === []) {
            return;
        }

        foreach ($outsiders as $outsiderId) {
            AttendanceSecurityLog::record(
                $tenantId, $outsiderId, $supervisor->branch_id, 'crew_not_supervisor', 'blocked', $lat ?: null, $lng ?: null
            );
        }

        throw new ApiFailure(
            __('messages.name_not_in_crew'),
            403,
            'CREW_NOT_SUPERVISOR',
            ['employee_ids' => $outsiders],
        );
    }

    /**
     * @param  list<int>  $employeeIds
     * @return array{count: int, recorded: list<int>, skipped: array<int, string>}
     */
    private function recordArrivals(
        array $employeeIds,
        int $branchId,
        int $tenantId,
        int $supervisorId,
        float $latitude,
        float $longitude,
        ?string $photo,
    ): array {
        $now = TenantClock::now($tenantId);
        $today = $now->format('Y-m-d');
        $time = $now->format('H:i:s');

        $recorded = [];
        $skipped = [];

        foreach ($employeeIds as $employeeId) {
            $existing = DB::table('attendance')
                ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)->where('date', $today)
                ->first(['id', 'check_in_time']);

            // A row with no time is a placeholder written once a shift ended.
            // That converts into a real arrival; only a row that already has a
            // time is a genuine duplicate.
            if ($existing !== null && Value::string($existing->check_in_time) !== '') {
                $skipped[$employeeId] = 'already_checked_in';

                continue;
            }

            $values = [
                'branch_id' => $branchId,
                'check_in_time' => $time,
                'check_in_method' => 'crew_gps',
                'status' => 'present',
                'check_in_latitude' => $latitude,
                'check_in_longitude' => $longitude,
                'recorded_by_employee_id' => $supervisorId,
                'crew_photo' => $photo,
                'late_minutes' => $this->lateMinutes($employeeId, $tenantId, $today, $time),
            ];

            if ($existing !== null) {
                DB::table('attendance')->where('id', Value::int($existing->id))->update($values);
            } else {
                DB::table('attendance')->insert($values + [
                    'tenant_id' => $tenantId,
                    'employee_id' => $employeeId,
                    'date' => $today,
                ]);
            }

            $recorded[] = $employeeId;
        }

        return ['count' => count($recorded), 'recorded' => $recorded, 'skipped' => $skipped];
    }

    /**
     * @param  list<int>  $employeeIds
     * @return array{count: int, recorded: list<int>, skipped: array<int, string>}
     */
    private function recordDepartures(array $employeeIds, int $tenantId, int $supervisorId, ?string $photo): array
    {
        $now = TenantClock::now($tenantId);
        $today = $now->format('Y-m-d');
        $time = $now->format('H:i:s');

        $recorded = [];
        $skipped = [];

        foreach ($employeeIds as $employeeId) {
            $existing = DB::table('attendance')
                ->where('employee_id', $employeeId)->where('tenant_id', $tenantId)->where('date', $today)
                ->first(['id', 'check_in_time', 'check_out_time']);

            if ($existing === null || Value::string($existing->check_in_time) === '') {
                $skipped[$employeeId] = 'not_checked_in';

                continue;
            }

            if (Value::string($existing->check_out_time) !== '') {
                $skipped[$employeeId] = 'already_checked_out';

                continue;
            }

            $checkIn = strtotime(Value::string($existing->check_in_time));
            $checkOut = strtotime($time);

            DB::table('attendance')->where('id', Value::int($existing->id))->update([
                'check_out_time' => $time,
                'check_out_method' => 'crew_gps',
                'recorded_by_employee_id' => $supervisorId,
                'crew_photo' => $photo,
                'worked_minutes' => $checkIn === false || $checkOut === false
                    ? 0
                    : (int) max(0, ($checkOut - $checkIn) / 60),
            ]);

            $recorded[] = $employeeId;
        }

        return ['count' => count($recorded), 'recorded' => $recorded, 'skipped' => $skipped];
    }

    private function lateMinutes(int $employeeId, int $tenantId, string $date, string $time): int
    {
        $scheduled = DB::table('employee_shift_schedule as ess')
            ->leftJoin('shifts as s', 's.id', '=', 'ess.shift_id')
            ->where('ess.employee_id', $employeeId)
            ->where('ess.tenant_id', $tenantId)
            ->where('ess.work_date', $date)
            ->where('ess.status', 'published')
            ->value('s.start_time');

        $expected = Value::string($scheduled);
        if ($expected === '') {
            $expected = Value::string(
                DB::table('employees')->where('id', $employeeId)->value('work_start_time'),
                '09:00:00'
            );
        }

        $actualAt = strtotime($time);
        $expectedAt = strtotime($expected);

        return $actualAt === false || $expectedAt === false
            ? 0
            : (int) max(0, ($actualAt - $expectedAt) / 60);
    }

    private function rejectsMockLocation(int $tenantId): bool
    {
        return Value::int(DB::table('tenants')->where('id', $tenantId)->value('reject_mock_location')) === 1;
    }
}
