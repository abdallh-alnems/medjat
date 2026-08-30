<?php

declare(strict_types=1);

namespace App\Domain\Devices;

use App\Domain\Time\TenantClock;
use App\Models\Attendance;
use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * Turns raw terminal punches into attendance.
 *
 * Two rules govern everything here. Store first, decide later: the device
 * deletes its own copy once it is answered, so every line is written before any
 * judgement is made about it, and a punch that cannot be used yet is a row with
 * a state rather than a discarded line. And never abort a batch: nothing here
 * throws, because a device that receives anything but a success re-sends the
 * same batch forever.
 *
 * Punch timestamps are the terminal's wall clock — it is bolted to a wall at
 * the branch — so "now" is read in the company's zone and never from PHP's,
 * which runs UTC.
 */
final class PunchIngestor
{
    /** A tap closer than this to the previous one is the same person twice. */
    private const DEFAULT_MIN_INTERVAL = 60;

    /** How long after an arrival a punch can still close that shift. */
    private const OPEN_SHIFT_WINDOW_HOURS = 16;

    /**
     * Punches outside this window are a terminal with a wrong clock, not
     * attendance. The future allowance is generous because the realistic
     * failure is a device left on the wrong timezone, and those punches are
     * still worth having; a clock stuck in 2035 is not.
     */
    private const SANE_PAST_DAYS = 60;

    private const SANE_FUTURE_MINUTES = 720;

    /**
     * What one stored punch means, written to attendance and recorded on the
     * punch row.
     *
     * @param  array<string, mixed>  $device
     * @param  array<string, mixed>  $punch
     */
    public function apply(array $device, array $punch, string $now): string
    {
        $punchId = Value::int($punch['id'] ?? null);
        $punchedAt = Value::string($punch['punched_at'] ?? null);
        $tenantId = Value::int($device['tenant_id'] ?? null);
        $deviceId = Value::int($device['id'] ?? null);

        // An unclaimed device has no company to file against. The punch is kept
        // so it can be replayed the moment the serial is entered.
        if ($tenantId <= 0) {
            return $this->record($punchId, 'unmatched', null, null, null, 'Device not registered to a company yet');
        }

        if (! self::isSaneTimestamp($punchedAt, $now)) {
            return $this->record($punchId, 'ignored', null, null, null, 'Device clock is out of range');
        }

        $mapping = DeviceUsers::find($deviceId, Value::string($punch['device_user_id'] ?? null));
        $employeeId = $mapping === null ? 0 : Value::int($mapping['employee_id'] ?? null);

        if ($employeeId <= 0) {
            return $this->record($punchId, 'unmatched', null, null, null, 'User ID is not linked to an employee');
        }

        $branchId = Value::nullableInt($device['branch_id'] ?? null);

        if ($branchId === null) {
            return $this->record($punchId, 'failed', $employeeId, null, null, 'Device is not assigned to a branch');
        }

        $exists = DB::table('employees')->where('id', $employeeId)->where('tenant_id', $tenantId)->exists();

        if (! $exists) {
            return $this->record($punchId, 'failed', $employeeId, null, null, 'Employee no longer exists');
        }

        $interval = Value::int($device['min_interval_seconds'] ?? null, self::DEFAULT_MIN_INTERVAL);

        if ($this->isRepeatTap($employeeId, $tenantId, $punchId, $punchedAt, $interval)) {
            return $this->record($punchId, 'duplicate', $employeeId, null, null, "Repeat tap within {$interval}s");
        }

        $date = substr($punchedAt, 0, 10);
        $time = substr($punchedAt, 11, 8);

        $decision = $this->resolveDirection($device, $employeeId, $tenantId, $date, $time, $punch);

        if ($decision['direction'] === null) {
            return $this->record($punchId, 'ignored', $employeeId, null, null, $decision['note'] ?? null);
        }

        $result = $decision['direction'] === 'in'
            ? Attendance::recordDeviceIn(
                $employeeId, $branchId, $tenantId, $date, $time,
                ZktecoProtocol::recognitionMethod(Value::nullableInt($punch['verify_mode'] ?? null)),
            )
            : Attendance::recordDeviceOut(
                $employeeId, $tenantId,
                $decision['date'] ?? $date,
                $time,
                $decision['attendance_id'] ?? null,
            );

        if ($result['attendance_id'] === null) {
            return $this->record($punchId, 'failed', $employeeId, $decision['direction'], null, $result['note']);
        }

        return $this->record(
            $punchId,
            'applied',
            $employeeId,
            $decision['direction'],
            $result['attendance_id'],
            $result['changed'] ? null : $result['note'],
        );
    }

    /**
     * Replays the punches that arrived before a User ID was linked.
     *
     * Called the moment HR makes the link, so the day the device was installed
     * — when everybody is enrolled and everybody taps — is not lost.
     *
     * @param  array<string, mixed>  $device
     * @return array<string, int>
     */
    public function replayForDeviceUser(array $device, string $deviceUserId): array
    {
        $counts = array_fill_keys(DevicePunches::STATES, 0);
        $now = self::now($device);

        foreach (DevicePunches::unmatchedFor(Value::int($device['id'] ?? null), $deviceUserId) as $row) {
            $state = $this->apply($device, [
                'id' => $row['id'] ?? null,
                'device_user_id' => $row['device_user_id'] ?? null,
                'punched_at' => $row['punched_at'] ?? null,
                'status_code' => $row['status_code'] ?? null,
                'verify_mode' => $row['verify_mode'] ?? null,
            ], $now);

            if (array_key_exists($state, $counts)) {
                $counts[$state]++;
            }
        }

        return $counts;
    }

    /**
     * In or out?
     *
     * Terminals almost never carry a reliable direction: staff walk up and put
     * a finger down without touching the function keys, so the status byte
     * reads "arrival" all day. Inferring it from the day's state is what every
     * working deployment ends up doing.
     *
     * @param  array<string, mixed>  $device
     * @param  array<string, mixed>  $punch
     * @return array{direction: string|null, date?: string, attendance_id?: int, note?: string}
     */
    private function resolveDirection(
        array $device,
        int $employeeId,
        int $tenantId,
        string $date,
        string $time,
        array $punch,
    ): array {
        if (Value::string($device['direction_mode'] ?? null, 'auto') === 'device_status') {
            $status = Value::int($punch['status_code'] ?? null);

            // 0 and 4 are arrivals, 1 and 5 departures; 2 and 3 are break
            // punches this does not model.
            if (in_array($status, [0, 4], true)) {
                return ['direction' => 'in'];
            }

            if (in_array($status, [1, 5], true)) {
                return ['direction' => 'out'];
            }

            return ['direction' => null, 'note' => "Break punch (status {$status}) is not tracked"];
        }

        // A shift left open on an earlier day and still within the window: the
        // 22:00 factory shift clocking out at 06:00 the next morning.
        $open = Attendance::findOpenShift($employeeId, $tenantId, $date);

        if ($open !== null) {
            $gap = self::hoursBetween($open['date'].' '.$open['check_in_time'], $date.' '.$time);

            if ($gap !== null && $gap > 0 && $gap <= self::OPEN_SHIFT_WINDOW_HOURS) {
                return ['direction' => 'out', 'date' => $open['date'], 'attendance_id' => $open['id']];
            }
        }

        $today = DB::table('attendance')
            ->where('employee_id', $employeeId)->where('date', $date)->where('tenant_id', $tenantId)
            ->first(['id', 'check_in_time']);

        if ($today === null || Value::string($today->check_in_time) === '') {
            return ['direction' => 'in'];
        }

        return ['direction' => 'out', 'attendance_id' => Value::int($today->id)];
    }

    private function record(
        int $punchId,
        string $state,
        ?int $employeeId,
        ?string $direction,
        ?int $attendanceId,
        ?string $note,
    ): string {
        DevicePunches::markResult($punchId, $state, $employeeId, $direction, $attendanceId, $note);

        return $state;
    }

    /** Another punch for the same person inside the device's dead time. */
    private function isRepeatTap(int $employeeId, int $tenantId, int $punchId, string $punchedAt, int $interval): bool
    {
        if ($interval <= 0) {
            return false;
        }

        return DB::table('device_punches')
            ->where('tenant_id', $tenantId)->where('employee_id', $employeeId)->where('id', '!=', $punchId)
            ->whereIn('state', ['applied', 'duplicate'])
            ->whereRaw('ABS(TIMESTAMPDIFF(SECOND, punched_at, ?)) < ?', [$punchedAt, $interval])
            ->exists();
    }

    /**
     * The company's local time, which is the same wall clock the terminal reads.
     *
     * @param  array<string, mixed>  $device
     */
    public static function now(array $device): string
    {
        $tenantId = Value::int($device['tenant_id'] ?? null);

        if ($tenantId > 0) {
            return TenantClock::timestamp($tenantId);
        }

        // An unclaimed device belongs to nobody yet, so there is no company
        // zone to read. The database's own clock is the nearest thing, and it
        // is what the punch timestamps were compared against before.
        $row = DB::selectOne('SELECT NOW() AS now');

        return is_object($row) ? Value::string($row->now ?? null, date('Y-m-d H:i:s')) : date('Y-m-d H:i:s');
    }

    public static function applyClockOffset(string $punchedAt, int $offsetMinutes): string
    {
        if ($offsetMinutes === 0) {
            return $punchedAt;
        }

        $at = strtotime($punchedAt);

        return $at === false ? $punchedAt : date('Y-m-d H:i:s', $at + $offsetMinutes * 60);
    }

    private static function isSaneTimestamp(string $punchedAt, string $now): bool
    {
        $punched = strtotime($punchedAt);
        $current = strtotime($now);

        if ($punched === false || $current === false) {
            return false;
        }

        if ($punched > $current + self::SANE_FUTURE_MINUTES * 60) {
            return false;
        }

        return $punched >= $current - self::SANE_PAST_DAYS * 86400;
    }

    private static function hoursBetween(string $from, string $to): ?float
    {
        $start = strtotime($from);
        $end = strtotime($to);

        if ($start === false || $end === false) {
            return null;
        }

        return ($end - $start) / 3600;
    }
}
