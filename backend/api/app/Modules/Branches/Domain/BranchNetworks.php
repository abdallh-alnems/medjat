<?php

declare(strict_types=1);

namespace App\Modules\Branches\Domain;

use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Facades\DB;

/**
 * The networks that count as "at the branch".
 *
 * Approved networks are what WiFi-backed attendance checks against; sightings
 * are what real check-ins observed, and they are how the approved list gets
 * built without somebody reading BSSIDs off a router.
 *
 * The distinction matters because one router is usually several networks: a
 * dual-band access point broadcasts a separate address per band, plus one per
 * guest network. Approving only some of them locks out whoever's phone happens
 * to prefer the other.
 */
final class BranchNetworks
{
    public const KINDS = ['bssid', 'ip_v4', 'ip_cidr'];

    /** How far back the approval screen looks by default. */
    public const SIGHTING_WINDOW_DAYS = 14;

    /**
     * Approves a network, reviving one that was switched off before.
     *
     * A router that was deactivated and later seen again should simply come
     * back rather than fail on the unique key.
     */
    public static function approve(
        int $tenantId,
        int $branchId,
        string $kind,
        string $value,
        ?string $label,
        string $source,
        ?int $adminId,
    ): void {
        DB::statement(
            'INSERT INTO branch_networks'
            .' (tenant_id, branch_id, kind, value, label, source, is_active, approved_by, approved_at)'
            .' VALUES (?, ?, ?, ?, ?, ?, 1, ?, NOW())'
            .' ON DUPLICATE KEY UPDATE'
            .'  label = VALUES(label), source = VALUES(source), is_active = 1,'
            .'  approved_by = VALUES(approved_by), approved_at = NOW()',
            [$tenantId, $branchId, $kind, $value, $label, $source, $adminId],
        );
    }

    /**
     * Switched off rather than deleted, so the audit trail survives.
     *
     * @param  list<int>  $ids
     */
    public static function deactivate(int $tenantId, int $branchId, array $ids): int
    {
        if ($ids === []) {
            return 0;
        }

        return DB::table('branch_networks')
            ->where('tenant_id', $tenantId)->where('branch_id', $branchId)->whereIn('id', $ids)
            ->update(['is_active' => 0]);
    }

    /**
     * Branches whose only network control is BSSID-based.
     *
     * Named specifically rather than counted, because on the browser channel a
     * BSSID rule is no control at all — a page cannot see an access point — and
     * a warning that says which branches is actionable where a number is not.
     *
     * @return list<array{id: int, name: string}>
     */
    public static function branchesWithoutIpControl(int $tenantId): array
    {
        $rows = DB::table('branches as b')
            ->where('b.tenant_id', $tenantId)
            ->whereNotExists(function (QueryBuilder $query): void {
                $query->select(DB::raw(1))
                    ->from('branch_networks as bn')
                    ->whereColumn('bn.tenant_id', 'b.tenant_id')
                    ->whereColumn('bn.branch_id', 'b.id')
                    ->where('bn.is_active', 1)
                    ->whereIn('bn.kind', ['ip_v4', 'ip_cidr']);
            })
            ->orderBy('b.name')
            ->get(['b.id', 'b.name'])
            ->all();

        return array_values(array_map(
            static function (mixed $row): array {
                /** @var array<string, mixed> $columns */
                $columns = (array) $row;

                return [
                    'id' => Value::int($columns['id'] ?? null),
                    'name' => Value::string($columns['name'] ?? null),
                ];
            },
            $rows,
        ));
    }

    /**
     * Distinct networks seen at a branch, with the counts that tell an office
     * router apart from somebody's home one.
     *
     * @return list<array<string, mixed>>
     */
    public static function sightingsFor(int $branchId, int $tenantId, int $days = self::SIGHTING_WINDOW_DAYS): array
    {
        $days = max(1, min(90, $days));

        $rows = DB::table('branch_network_sightings as s')
            ->leftJoin('branch_networks as n', function (JoinClause $join): void {
                $join->on('n.tenant_id', '=', 's.tenant_id')
                    ->on('n.branch_id', '=', 's.branch_id')
                    ->where('n.kind', '=', 'bssid')
                    ->on('n.value', '=', 's.bssid');
            })
            ->where('s.tenant_id', $tenantId)->where('s.branch_id', $branchId)
            ->whereNotNull('s.bssid')
            ->whereRaw('s.seen_at >= DATE_SUB(NOW(), INTERVAL ? DAY)', [$days])
            ->groupBy('s.bssid')
            ->orderByDesc('sightings')
            ->get([
                's.bssid',
                DB::raw('MAX(s.ssid) AS ssid'),
                DB::raw('COUNT(*) AS sightings'),
                DB::raw('SUM(s.inside_geofence) AS inside_count'),
                DB::raw('COUNT(DISTINCT s.employee_id) AS employee_count'),
                DB::raw('MAX(s.seen_at) AS last_seen'),
                DB::raw('MAX(n.id IS NOT NULL AND n.is_active = 1) AS is_approved'),
            ])
            ->all();

        return array_values(array_map(
            static function (mixed $row): array {
                /** @var array<string, mixed> $columns */
                $columns = (array) $row;

                return $columns;
            },
            $rows,
        ));
    }

    /**
     * The denominator for the coverage figure.
     *
     * Sightings with no address — mobile data, or iOS without the entitlement —
     * are excluded: they can never be covered by a list of addresses, and
     * counting them would understate the coverage and scare an administrator
     * off a setting that would in fact work.
     */
    public static function sightingTotal(int $branchId, int $tenantId, int $days = self::SIGHTING_WINDOW_DAYS): int
    {
        $days = max(1, min(90, $days));

        return Value::int(
            DB::table('branch_network_sightings')
                ->where('tenant_id', $tenantId)->where('branch_id', $branchId)
                ->whereNotNull('bssid')
                ->whereRaw('seen_at >= DATE_SUB(NOW(), INTERVAL ? DAY)', [$days])
                ->count()
        );
    }
}
