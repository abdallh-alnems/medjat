<?php

declare(strict_types=1);

namespace App\Domain\Devices;

use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;

/**
 * The raw punch log, exactly as the terminals sent it.
 *
 * Written before any rule is applied, because the device wipes its own copy as
 * soon as we answer OK. A punch that is not stored here is gone forever, so
 * nothing in this class may refuse a row — a punch we cannot use yet is a row
 * with a state, never a discarded line.
 */
final class DevicePunches
{
    public const STATES = ['applied', 'duplicate', 'unmatched', 'ignored', 'failed'];

    /**
     * Stores one punch, reporting whether the device had already sent it.
     *
     * Terminals re-send their whole buffer after a power cut, so a repeat is
     * routine rather than an error.
     *
     * @return array{id: int, duplicate: bool, state: string|null}
     */
    public static function record(
        int $deviceId,
        ?int $tenantId,
        string $deviceUserId,
        string $punchedAt,
        ?int $statusCode,
        ?int $verifyMode,
        ?string $workCode,
        ?string $rawLine,
    ): array {
        $deviceUserId = trim($deviceUserId);

        $affected = DB::affectingStatement(
            'INSERT INTO device_punches'
            .' (tenant_id, device_id, device_user_id, punched_at, status_code, verify_mode, work_code, raw_line)'
            .' VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
            .' ON DUPLICATE KEY UPDATE id = id',
            [$tenantId, $deviceId, $deviceUserId, $punchedAt, $statusCode, $verifyMode, $workCode, $rawLine],
        );

        $row = DB::table('device_punches')
            ->where('device_id', $deviceId)->where('device_user_id', $deviceUserId)->where('punched_at', $punchedAt)
            ->first(['id', 'state']);

        return [
            'id' => $row === null ? 0 : Value::int($row->id),
            'duplicate' => $affected === 0,
            'state' => $row === null ? null : Value::nullableString($row->state),
        ];
    }

    public static function markResult(
        int $punchId,
        string $state,
        ?int $employeeId = null,
        ?string $direction = null,
        ?int $attendanceId = null,
        ?string $note = null,
    ): void {
        DB::table('device_punches')->where('id', $punchId)->update([
            'state' => $state,
            'employee_id' => $employeeId,
            'direction' => $direction,
            'attendance_id' => $attendanceId,
            'note' => $note === null ? null : mb_substr($note, 0, 191),
        ]);
    }

    /**
     * Punches recorded for a User ID before anybody linked it.
     *
     * Replayed the moment the link is made, so the day a device was installed —
     * when everybody is enrolled and everybody taps — is not lost while HR is
     * still matching names to numbers.
     *
     * @return list<array<string, mixed>>
     */
    public static function unmatchedFor(int $deviceId, string $deviceUserId, int $limit = 500): array
    {
        $rows = DB::table('device_punches')
            ->where('device_id', $deviceId)->where('device_user_id', trim($deviceUserId))
            ->where('state', 'unmatched')
            ->orderBy('punched_at')
            ->limit(max(1, min(2000, $limit)))
            ->get()->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    /**
     * The feed behind "the machine didn't record me": either the punch is here
     * and shows why it was not applied, or it never arrived — a very different
     * conversation.
     *
     * @param  array<string, mixed>  $filters
     * @return list<array<string, mixed>>
     */
    public static function listForTenant(int $tenantId, array $filters = [], int $limit = 100): array
    {
        $rows = DB::table('device_punches as p')
            ->leftJoin('employees as e', function (JoinClause $join): void {
                $join->on('e.id', '=', 'p.employee_id')->on('e.tenant_id', '=', 'p.tenant_id');
            })
            ->leftJoin('attendance_devices as d', 'd.id', '=', 'p.device_id')
            ->leftJoin('device_users as du', function (JoinClause $join): void {
                $join->on('du.device_id', '=', 'p.device_id')
                    ->on('du.device_user_id', '=', 'p.device_user_id');
            })
            ->where('p.tenant_id', $tenantId)
            ->when($filters['device_id'] ?? null, fn (QueryBuilder $q, mixed $v): QueryBuilder => $q->where('p.device_id', $v))
            ->when($filters['state'] ?? null, fn (QueryBuilder $q, mixed $v): QueryBuilder => $q->where('p.state', $v))
            ->when($filters['employee_id'] ?? null, fn (QueryBuilder $q, mixed $v): QueryBuilder => $q->where('p.employee_id', $v))
            ->when($filters['date_from'] ?? null, fn (QueryBuilder $q, mixed $v): QueryBuilder => $q->where('p.punched_at', '>=', Value::string($v).' 00:00:00'))
            ->when($filters['date_to'] ?? null, fn (QueryBuilder $q, mixed $v): QueryBuilder => $q->where('p.punched_at', '<=', Value::string($v).' 23:59:59'))
            ->orderByDesc('p.punched_at')
            ->limit(max(1, min(500, $limit)))
            ->get([
                'p.id', 'p.device_id', 'p.device_user_id', 'p.employee_id', 'p.punched_at',
                'p.direction', 'p.state', 'p.note', 'p.verify_mode', 'p.attendance_id',
                'e.name as employee_name', 'd.name as device_name', 'd.serial_number',
                'du.device_name as device_user_name',
            ])
            ->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    /**
     * @return array<string, int>
     */
    public static function statsForDevice(int $deviceId, int $tenantId): array
    {
        $counts = array_fill_keys(self::STATES, 0);

        $rows = DB::table('device_punches')
            ->where('device_id', $deviceId)->where('tenant_id', $tenantId)
            ->groupBy('state')
            ->get(['state', DB::raw('COUNT(*) AS c')]);

        foreach ($rows as $row) {
            $state = Value::string($row->state);

            if (array_key_exists($state, $counts)) {
                $counts[$state] = Value::int($row->c);
            }
        }

        return $counts;
    }

    /** Punches captured before the device was claimed belong to the claimer. */
    public static function adoptOrphans(int $deviceId, int $tenantId): int
    {
        return DB::table('device_punches')->where('device_id', $deviceId)->whereNull('tenant_id')
            ->update(['tenant_id' => $tenantId]);
    }

    /**
     * @return array<string, mixed>
     */
    private static function toArray(mixed $row): array
    {
        /** @var array<string, mixed> $columns */
        $columns = (array) $row;

        return $columns;
    }
}
