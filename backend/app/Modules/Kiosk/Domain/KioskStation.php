<?php

declare(strict_types=1);

namespace App\Modules\Kiosk\Domain;

use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

/**
 * A tablet in service at one branch.
 *
 * Revocation is a state, never a delete: attendance rows point here, and
 * historical attendance must keep resolving to the device that recorded it long
 * after that device has been retired.
 */
final class KioskStation
{
    /** How long a kiosk may go unseen before it counts as dark. */
    public const OFFLINE_AFTER_MINUTES = 30;

    public static function create(
        int $tenantId,
        int $branchId,
        ?string $name,
        ?string $deviceModel,
        string $platform,
        ?string $appVersion,
        ?int $pairedBy,
    ): int {
        return (int) DB::table('attendance_stations')->insertGetId([
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'name' => $name,
            'device_model' => $deviceModel,
            'platform' => $platform,
            'app_version' => $appVersion,
            'paired_by' => $pairedBy,
            'paired_at' => DB::raw('NOW()'),
            'last_seen_at' => DB::raw('NOW()'),
        ]);
    }

    /**
     * @return array<string, mixed>|null
     */
    public static function find(int $stationId, int $tenantId): ?array
    {
        $row = DB::table('attendance_stations')
            ->where('id', $stationId)->where('tenant_id', $tenantId)
            ->first();

        return $row === null ? null : self::toArray($row);
    }

    /**
     * The fleet, for the management app.
     *
     * Whether a station is dark is decided here rather than in the client, so
     * every surface agrees on what dark means. Thirty minutes is deliberately
     * generous: a kiosk heartbeats often, and a brief network blip at a branch
     * should not page anybody.
     *
     * @return list<array<string, mixed>>
     */
    public static function listForTenant(int $tenantId, ?int $branchId = null): array
    {
        $rows = DB::table('attendance_stations as s')
            ->join('branches as b', 'b.id', '=', 's.branch_id')
            ->where('s.tenant_id', $tenantId)
            ->when($branchId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('s.branch_id', $branchId))
            ->orderBy('b.name')->orderBy('s.name')
            ->get([
                's.*', 'b.name as branch_name',
                DB::raw(
                    '(s.last_seen_at IS NULL OR s.last_seen_at < DATE_SUB(NOW(), INTERVAL '
                    .self::OFFLINE_AFTER_MINUTES.' MINUTE)) AS is_offline'
                ),
            ])
            ->all();

        return array_values(array_map(self::toArray(...), $rows));
    }

    /** Called on every authenticated request, so it stays a single cheap write. */
    public static function touchSeen(int $stationId, ?string $ip, ?string $appVersion): void
    {
        DB::update(
            'UPDATE attendance_stations'
            .' SET last_seen_at = NOW(), last_ip = COALESCE(?, last_ip), app_version = COALESCE(?, app_version)'
            .' WHERE id = ?',
            [$ip, $appVersion, $stationId],
        );
    }

    public static function recordPunch(int $stationId): void
    {
        DB::table('attendance_stations')->where('id', $stationId)->update([
            'punch_count' => DB::raw('punch_count + 1'),
            'last_punch_at' => DB::raw('NOW()'),
        ]);
    }

    /**
     * Revoking the station revokes its token too — a live credential pointing
     * at a retired station is exactly the state this feature must not have.
     */
    public static function revoke(int $stationId, int $tenantId, ?int $revokedBy): bool
    {
        $affected = DB::table('attendance_stations')
            ->where('id', $stationId)->where('tenant_id', $tenantId)->where('status', 'active')
            ->update(['status' => 'revoked', 'revoked_at' => DB::raw('NOW()'), 'revoked_by' => $revokedBy]);

        if ($affected > 0) {
            KioskToken::revokeForStation($stationId, 'unpaired');

            return true;
        }

        return false;
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
