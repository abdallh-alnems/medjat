<?php

declare(strict_types=1);

namespace App\Models;

use App\Domain\Time\TenantClock;
use App\Exceptions\ApiFailure;
use App\Support\Value;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

/**
 * One row per employee per day.
 *
 * @property int $id
 * @property int $tenant_id
 * @property int $employee_id
 * @property int|null $branch_id
 * @property string $date
 * @property string|null $check_in_time
 * @property string|null $check_out_time
 * @property string $status
 */
final class Attendance extends Model
{
    protected $table = 'attendance';

    public $timestamps = false;

    protected $guarded = [];

    /**
     * @param  Builder<self>  $query
     * @return Builder<self>
     */
    public function scopeForTenant(Builder $query, int $tenantId): Builder
    {
        return $query->where('tenant_id', $tenantId);
    }

    public static function forDay(int $employeeId, int $tenantId, string $date): ?self
    {
        /** @var self|null */
        return self::query()
            ->forTenant($tenantId)
            ->where('employee_id', $employeeId)
            ->where('date', $date)
            ->first();
    }

    /**
     * Records an arrival and returns the row id.
     *
     * Stamped in the company's timezone, which is what every read path and the
     * shift times compared against below already use. A bare date() here records
     * UTC, and then no arrival ever counts as late.
     *
     * @return int The attendance row id.
     *
     * @throws ApiFailure When the employee has already checked in today.
     */
    public static function recordCheckIn(
        int $employeeId,
        int $branchId,
        int $tenantId,
        string $method,
        ?float $latitude = null,
        ?float $longitude = null,
        bool $isVpn = false,
        ?string $recognitionMethod = null,
        ?float $recognitionConfidence = null,
        ?string $atTime = null,
    ): int {
        $now = TenantClock::now($tenantId);
        $today = $now->format('Y-m-d');
        $time = $atTime ?? $now->format('H:i:s');

        $existing = self::forDay($employeeId, $tenantId, $today);

        // A genuine duplicate has an actual check-in time. A row with a NULL
        // check_in_time is a placeholder — an 'absent' row written once the
        // shift ended — and that has to convert into a real check-in rather
        // than block one, or the employee can never check in at all.
        if ($existing !== null && $existing->check_in_time !== null && $existing->check_in_time !== '') {
            throw new ApiFailure('Already checked in today', 400);
        }

        $lateMinutes = self::lateMinutes($employeeId, $tenantId, $today, $time);

        $values = [
            'branch_id' => $branchId,
            'check_in_time' => $time,
            'check_in_method' => $method,
            'late_minutes' => $lateMinutes,
            'status' => 'present',
            'check_in_latitude' => $latitude,
            'check_in_longitude' => $longitude,
            'is_vpn' => $isVpn ? 1 : 0,
            'recognition_method' => $recognitionMethod,
            'recognition_confidence' => $recognitionConfidence,
        ];

        if ($existing !== null) {
            self::query()->whereKey($existing->id)->update($values);

            return $existing->id;
        }

        return (int) self::query()->insertGetId($values + [
            'tenant_id' => $tenantId,
            'employee_id' => $employeeId,
            'date' => $today,
        ]);
    }

    /**
     * True when today is open: checked in and not yet out.
     *
     * Used to let someone close a day the company disabled their channel
     * halfway through — the policy applies to new days, not to hours already
     * worked.
     */
    public static function hasOpenDay(int $employeeId, int $tenantId): bool
    {
        return self::query()
            ->forTenant($tenantId)
            ->where('employee_id', $employeeId)
            ->where('date', TenantClock::date($tenantId))
            ->whereNotNull('check_in_time')
            ->whereNull('check_out_time')
            ->exists();
    }

    /**
     * Records a departure and computes the day's totals.
     *
     * Same company clock as the arrival: the row was keyed on that date, and the
     * overtime arithmetic compares against shift times expressed in that zone.
     *
     * @throws ApiFailure When there is nothing open to close.
     */
    public static function recordCheckOut(int $employeeId, int $tenantId, ?string $atTime = null): void
    {
        $now = TenantClock::now($tenantId);
        $today = $now->format('Y-m-d');
        $time = $atTime ?? $now->format('H:i:s');

        $record = self::forDay($employeeId, $tenantId, $today);

        if ($record === null) {
            throw new ApiFailure('No check-in record found for today', 404);
        }

        if ($record->check_in_time === null || $record->check_in_time === '') {
            // A placeholder row with no arrival: there is no session to close.
            throw new ApiFailure('No check-in record found for today', 404);
        }

        $checkIn = strtotime($record->check_in_time);
        $checkOut = strtotime($time);

        if ($checkIn === false || $checkOut === false) {
            throw new ApiFailure('No check-in record found for today', 404);
        }

        [$shiftStart, $shiftEnd] = self::shiftWindow($employeeId, $tenantId, $today);

        $startAt = strtotime($shiftStart);
        $endAt = strtotime($shiftEnd);

        self::query()->whereKey($record->id)->update([
            'check_out_time' => $time,
            'worked_minutes' => (int) max(0, ($checkOut - $checkIn) / 60),
            'overtime_minutes' => $endAt === false ? 0 : (int) max(0, ($checkOut - $endAt) / 60),
            // Recomputed rather than trusted: the arrival may have been edited
            // by an administrator since it was stamped.
            'late_minutes' => $startAt === false ? 0 : (int) max(0, ($checkIn - $startAt) / 60),
        ]);
    }

    /**
     * The day's shift window, falling back to the employee's standing hours and
     * then to 09:00–17:00.
     *
     * @return array{string, string}
     */
    private static function shiftWindow(int $employeeId, int $tenantId, string $date): array
    {
        $shift = DB::table('employee_shift_schedule as ess')
            ->leftJoin('shifts as s', 's.id', '=', 'ess.shift_id')
            ->where('ess.employee_id', $employeeId)
            ->where('ess.tenant_id', $tenantId)
            ->where('ess.work_date', $date)
            ->where('ess.status', 'published')
            ->first(['s.start_time', 's.end_time']);

        $employee = DB::table('employees')->where('id', $employeeId)
            ->first(['work_start_time', 'work_end_time']);

        $start = Value::string($shift?->start_time);
        $end = Value::string($shift?->end_time);

        return [
            $start !== '' ? $start : Value::string($employee?->work_start_time, '09:00:00'),
            $end !== '' ? $end : Value::string($employee?->work_end_time, '17:00:00'),
        ];
    }

    /**
     * Minutes late against the shift scheduled for that day, falling back to the
     * employee's standing start time and then to 09:00.
     *
     * Only a *published* rotation counts. A draft schedule is a manager still
     * thinking, and measuring someone's lateness against it would penalise them
     * for a shift nobody has agreed to yet.
     */
    private static function lateMinutes(int $employeeId, int $tenantId, string $date, string $time): int
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

        if ($actualAt === false || $expectedAt === false) {
            return 0;
        }

        return (int) max(0, ($actualAt - $expectedAt) / 60);
    }

    /**
     * Records which channel a punch arrived on, and the evidence image if one
     * was captured.
     *
     * The column name is built from $punch, so it is checked against a literal
     * allow-list first rather than trusted — this is the one place in the module
     * where an identifier rather than a value goes into SQL.
     *
     * COALESCE, not assignment: a later punch without a photo must not erase the
     * image an earlier one captured.
     */
    public static function recordChannel(
        int $tenantId,
        int $employeeId,
        string $date,
        string $punch,
        string $origin,
        ?string $photo = null,
    ): void {
        if (! in_array($punch, ['check_in', 'check_out'], true)) {
            return;
        }

        DB::update(
            "UPDATE attendance
                SET {$punch}_origin = ?, {$punch}_photo = COALESCE(?, {$punch}_photo)
              WHERE tenant_id = ? AND employee_id = ? AND date = ?",
            [$origin, $photo, $tenantId, $employeeId, $date]
        );
    }
}
