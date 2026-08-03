<?php

/**
 * Turns raw terminal punches into attendance rows.
 *
 * Two rules govern everything here:
 *
 *  1. Store first, decide later. The device deletes its copy once we answer OK,
 *     so every line is written to `device_punches` before any judgement is made
 *     about it. A punch we cannot use yet is a row with a state, never a
 *     discarded line.
 *
 *  2. Never abort a batch. No method here calls Response::fail — a device that
 *     receives anything other than a 200 re-sends the same batch forever.
 *
 * Time frame: punch timestamps are the terminal's wall clock, which is the
 * company's local time (the device is bolted to the wall at the branch). "Now"
 * is therefore read from MySQL, which runs on local time, and never from PHP's
 * date() — the PHP process runs in UTC.
 */
final class DevicePunchIngestor {
    /** A tap closer than this to the previous one is the same person tapping twice. */
    private const DEFAULT_MIN_INTERVAL = 60;

    /** How long after a check-in a punch can still close that shift (night shifts). */
    private const OPEN_SHIFT_WINDOW_HOURS = 16;

    /**
     * Punches outside this window are a terminal with a wrong clock, not
     * attendance, and are quarantined instead of written to the attendance
     * table. The future allowance is a generous 12 hours because the realistic
     * failure is a device left on the wrong timezone, and those punches are
     * still worth recording; a clock stuck in 2000 or 2035 is not.
     */
    private const SANE_PAST_DAYS = 60;
    private const SANE_FUTURE_MINUTES = 720;

    /** Company local time, read from the database because PHP runs in UTC. */
    public static function now(): string {
        $row = Database::fetchOne("SELECT NOW() AS now");
        return $row['now'] ?? date('Y-m-d H:i:s');
    }

    /**
     * Ingests an ATTLOG payload. Returns the number of lines accepted, which is
     * what the device wants echoed back.
     */
    public static function ingestAttlog(array $device, string $body): int {
        $accepted = 0;
        $now = self::now();

        foreach (preg_split('/\r\n|\n|\r/', $body) ?: [] as $line) {
            $parsed = ZktecoAdms::parseAttlogLine($line);
            if ($parsed === null) {
                continue;
            }

            $punchedAt = self::applyClockOffset($parsed['punched_at'], (int) $device['clock_offset_minutes']);

            $stored = DevicePunchModel::record(
                (int) $device['id'],
                $device['tenant_id'] !== null ? (int) $device['tenant_id'] : null,
                $parsed['pin'],
                $punchedAt,
                $parsed['status'],
                $parsed['verify'],
                $parsed['work_code'],
                $parsed['raw']
            );
            $accepted++;

            if ($stored['duplicate']) {
                continue;
            }

            DeviceUserModel::ensure(
                (int) $device['id'],
                $device['tenant_id'] !== null ? (int) $device['tenant_id'] : null,
                $parsed['pin']
            );
            DeviceUserModel::touchPunch((int) $device['id'], $parsed['pin'], $punchedAt);
            AttendanceDeviceModel::touchPunch((int) $device['id'], $punchedAt);

            self::apply($device, [
                'id' => $stored['id'],
                'device_user_id' => $parsed['pin'],
                'punched_at' => $punchedAt,
                'status_code' => $parsed['status'],
                'verify_mode' => $parsed['verify'],
            ], $now);
        }

        return $accepted;
    }

    /** Ingests an OPERLOG payload — the device announcing its own user list. */
    public static function ingestOperlog(array $device, string $body): int {
        $seen = 0;
        foreach (preg_split('/\r\n|\n|\r/', $body) ?: [] as $line) {
            $parsed = ZktecoAdms::parseOperlogLine($line);
            if ($parsed === null || $parsed['kind'] !== 'user') {
                continue;
            }
            DeviceUserModel::ensure(
                (int) $device['id'],
                $device['tenant_id'] !== null ? (int) $device['tenant_id'] : null,
                $parsed['pin'],
                $parsed['name'],
                $parsed['card'],
                $parsed['privilege']
            );
            $seen++;
        }
        return $seen;
    }

    /**
     * Decides what a single stored punch means and writes it to `attendance`.
     * Always returns; the outcome is recorded on the punch row itself.
     */
    public static function apply(array $device, array $punch, ?string $now = null): string {
        $now = $now ?? self::now();
        $punchId = (int) $punch['id'];
        $punchedAt = $punch['punched_at'];

        // An unclaimed device has no company to file attendance against. The
        // punch is kept so it can be replayed the moment the serial is entered.
        if ($device['tenant_id'] === null || (int) $device['tenant_id'] === 0) {
            DevicePunchModel::markResult($punchId, 'unmatched', null, null, null, 'Device not registered to a company yet');
            return 'unmatched';
        }
        $tenantId = (int) $device['tenant_id'];

        if (!self::isSaneTimestamp($punchedAt, $now)) {
            DevicePunchModel::markResult($punchId, 'ignored', null, null, null, 'Device clock is out of range');
            return 'ignored';
        }

        $mapping = DeviceUserModel::find((int) $device['id'], $punch['device_user_id']);
        if (!$mapping || $mapping['employee_id'] === null) {
            DevicePunchModel::markResult($punchId, 'unmatched', null, null, null, 'User ID is not linked to an employee');
            return 'unmatched';
        }
        $employeeId = (int) $mapping['employee_id'];

        $branchId = $device['branch_id'] !== null ? (int) $device['branch_id'] : null;
        if ($branchId === null) {
            DevicePunchModel::markResult($punchId, 'failed', $employeeId, null, null, 'Device is not assigned to a branch');
            return 'failed';
        }

        $employee = EmployeeModel::findById($employeeId, $tenantId);
        if (!$employee) {
            DevicePunchModel::markResult($punchId, 'failed', $employeeId, null, null, 'Employee no longer exists');
            return 'failed';
        }

        $interval = (int) ($device['min_interval_seconds'] ?? self::DEFAULT_MIN_INTERVAL);
        if (self::isRepeatTap($employeeId, $tenantId, $punchId, $punchedAt, $interval)) {
            DevicePunchModel::markResult($punchId, 'duplicate', $employeeId, null, null, 'Repeat tap within ' . $interval . 's');
            return 'duplicate';
        }

        $date = substr($punchedAt, 0, 10);
        $time = substr($punchedAt, 11, 8);
        $recognition = ZktecoAdms::recognitionMethod(
            isset($punch['verify_mode']) ? (int) $punch['verify_mode'] : null
        );

        $decision = self::resolveDirection($device, $employeeId, $tenantId, $date, $time, $punch);

        if ($decision['direction'] === null) {
            DevicePunchModel::markResult($punchId, 'ignored', $employeeId, null, null, $decision['note']);
            return 'ignored';
        }

        if ($decision['direction'] === 'in') {
            $result = AttendanceModel::deviceCheckIn($employeeId, $branchId, $tenantId, $date, $time, $recognition);
        } else {
            $result = AttendanceModel::deviceCheckOut(
                $employeeId,
                $tenantId,
                $decision['date'] ?? $date,
                $time,
                $decision['attendance_id'] ?? null
            );
        }

        if ($result['attendance_id'] === null) {
            DevicePunchModel::markResult($punchId, 'failed', $employeeId, $decision['direction'], null, $result['note']);
            return 'failed';
        }

        DevicePunchModel::markResult(
            $punchId,
            'applied',
            $employeeId,
            $decision['direction'],
            (int) $result['attendance_id'],
            $result['changed'] ? null : $result['note']
        );
        return 'applied';
    }

    /**
     * In or out?
     *
     * Terminals almost never carry a reliable direction: staff walk up and put
     * a finger down without touching the F1/F2 keys, so the status byte reads
     * "check-in" all day. `auto` therefore infers it from the day's state,
     * which is what every working deployment ends up doing.
     */
    private static function resolveDirection(
        array $device,
        int $employeeId,
        int $tenantId,
        string $date,
        string $time,
        array $punch
    ): array {
        if (($device['direction_mode'] ?? 'auto') === 'device_status') {
            $status = isset($punch['status_code']) ? (int) $punch['status_code'] : 0;
            // 0/4 = in, 1/5 = out, 2/3 = break punches we do not model yet.
            if (in_array($status, [0, 4], true)) {
                return ['direction' => 'in'];
            }
            if (in_array($status, [1, 5], true)) {
                return ['direction' => 'out'];
            }
            return ['direction' => null, 'note' => 'Break punch (status ' . $status . ') is not tracked'];
        }

        // A shift left open on an earlier day and still within the window: the
        // 22:00 factory shift clocking out at 06:00 the next morning.
        $open = AttendanceModel::findOpenShiftRow($employeeId, $tenantId, $date);
        if ($open) {
            $gap = self::hoursBetween($open['date'] . ' ' . $open['check_in_time'], $date . ' ' . $time);
            if ($gap !== null && $gap > 0 && $gap <= self::OPEN_SHIFT_WINDOW_HOURS) {
                return [
                    'direction' => 'out',
                    'date' => $open['date'],
                    'attendance_id' => (int) $open['id'],
                ];
            }
        }

        $today = Database::fetchOne(
            "SELECT id, check_in_time FROM attendance
             WHERE employee_id = ? AND date = ? AND tenant_id = ? LIMIT 1",
            [$employeeId, $date, $tenantId]
        );

        if (!$today || empty($today['check_in_time'])) {
            return ['direction' => 'in'];
        }

        return ['direction' => 'out', 'attendance_id' => (int) $today['id']];
    }

    /**
     * Replays the punches that arrived before a User ID was linked. Called the
     * moment HR links the ID, so the day the device was installed is not lost.
     */
    public static function replayForDeviceUser(array $device, string $deviceUserId): array {
        $pending = DevicePunchModel::unmatchedFor((int) $device['id'], $deviceUserId);
        $now = self::now();
        $counts = ['applied' => 0, 'duplicate' => 0, 'ignored' => 0, 'failed' => 0, 'unmatched' => 0];

        foreach ($pending as $row) {
            $state = self::apply($device, [
                'id' => (int) $row['id'],
                'device_user_id' => $row['device_user_id'],
                'punched_at' => $row['punched_at'],
                'status_code' => $row['status_code'],
                'verify_mode' => $row['verify_mode'],
            ], $now);
            $counts[$state] = ($counts[$state] ?? 0) + 1;
        }

        return $counts;
    }

    private static function applyClockOffset(string $punchedAt, int $offsetMinutes): string {
        if ($offsetMinutes === 0) {
            return $punchedAt;
        }
        $ts = strtotime($punchedAt);
        return $ts === false ? $punchedAt : date('Y-m-d H:i:s', $ts + $offsetMinutes * 60);
    }

    private static function isSaneTimestamp(string $punchedAt, string $now): bool {
        $p = strtotime($punchedAt);
        $n = strtotime($now);
        if ($p === false || $n === false) {
            return false;
        }
        if ($p > $n + self::SANE_FUTURE_MINUTES * 60) {
            return false;
        }
        return $p >= $n - self::SANE_PAST_DAYS * 86400;
    }

    private static function hoursBetween(string $from, string $to): ?float {
        $a = strtotime($from);
        $b = strtotime($to);
        if ($a === false || $b === false) {
            return null;
        }
        return ($b - $a) / 3600;
    }

    /** Another punch for the same employee within the device's dead time. */
    private static function isRepeatTap(int $employeeId, int $tenantId, int $punchId, string $punchedAt, int $interval): bool {
        if ($interval <= 0) {
            return false;
        }
        $row = Database::fetchOne(
            "SELECT id FROM device_punches
             WHERE tenant_id = ? AND employee_id = ? AND id <> ?
               AND state IN ('applied','duplicate')
               AND ABS(TIMESTAMPDIFF(SECOND, punched_at, ?)) < ?
             LIMIT 1",
            [$tenantId, $employeeId, $punchId, $punchedAt, $interval]
        );
        return $row !== null;
    }

    /** Keeps the protocol debug table from growing without bound. */
    public static function pruneProtocolLogs(int $keepHours = 48): void {
        Database::execute(
            "DELETE FROM device_protocol_logs WHERE created_at < DATE_SUB(NOW(), INTERVAL ? HOUR)",
            [$keepHours]
        );
    }
}
