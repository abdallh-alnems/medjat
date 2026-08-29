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
