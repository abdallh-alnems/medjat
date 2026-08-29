<?php

/**
 * Approved WiFi networks per branch, plus the raw sightings that feed the
 * approval screen.
 */
final class BranchNetworkModel {
    /** Active approved networks for a branch. */
    public static function approvedFor(int $branchId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT id, kind, value, label
             FROM branch_networks
             WHERE tenant_id = ? AND branch_id = ? AND is_active = 1",
            [$tenantId, $branchId]
        );
    }

    /**
     * Branches with no approved IP network — the only network control a browser
     * can be held to.
     *
     * A BSSID row does not count here however many the branch has: the browser
     * cannot read the access point it is joined to, so a branch whose WiFi
     * control is entirely BSSID-based has *no* network constraint on this
     * channel even though its app attendance looks well guarded. The settings
     * screen names these branches rather than showing a general caution, so an
     * administrator can see exactly where the geofence is the only thing left.
     *
     * @return list<array{id:int,name:string}>
     */
    public static function branchesWithoutIpControl(int $tenantId): array {
        $rows = Database::fetchAll(
            "SELECT b.id, b.name
             FROM branches b
             WHERE b.tenant_id = ?
               AND NOT EXISTS (
                   SELECT 1 FROM branch_networks bn
                   WHERE bn.tenant_id = b.tenant_id
                     AND bn.branch_id = b.id
                     AND bn.is_active = 1
                     AND bn.kind IN ('ip_v4', 'ip_cidr')
               )
             ORDER BY b.name ASC",
            [$tenantId]
        );

        return array_map(
            static fn(array $r): array => ['id' => (int) $r['id'], 'name' => (string) $r['name']],
            $rows
        );
    }

    public static function hasAnyApproved(int $branchId, int $tenantId): bool {
        $row = Database::fetchOne(
            "SELECT 1 AS ok FROM branch_networks
             WHERE tenant_id = ? AND branch_id = ? AND is_active = 1 LIMIT 1",
            [$tenantId, $branchId]
        );
        return $row !== null;
    }

    /**
     * Approves a network. Re-approving an existing row reactivates it instead
     * of failing on the unique key — a router that was deactivated and later
     * seen again should simply come back.
     */
    public static function approve(
        int $tenantId,
        int $branchId,
        string $kind,
        string $value,
        ?string $label,
        string $source,
        ?int $adminId
    ): void {
        Database::execute(
            "INSERT INTO branch_networks
                (tenant_id, branch_id, kind, value, label, source, is_active, approved_by, approved_at)
             VALUES (?, ?, ?, ?, ?, ?, 1, ?, NOW())
             ON DUPLICATE KEY UPDATE
                label = VALUES(label),
                source = VALUES(source),
                is_active = 1,
                approved_by = VALUES(approved_by),
                approved_at = NOW()",
            [$tenantId, $branchId, $kind, $value, $label, $source, $adminId]
        );
    }

    /** Soft-deactivates rather than deleting, so the audit trail survives. */
    public static function deactivate(int $tenantId, int $branchId, array $ids): int {
        if (empty($ids)) {
            return 0;
        }
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        return Database::execute(
            "UPDATE branch_networks SET is_active = 0
             WHERE tenant_id = ? AND branch_id = ? AND id IN ({$placeholders})",
            array_merge([$tenantId, $branchId], array_map('intval', $ids))
        );
    }

    public static function recordSighting(array $row): void {
        // A failed sighting insert must never break a check-in.
        try {
            Database::execute(
                "INSERT INTO branch_network_sightings
                    (tenant_id, branch_id, employee_id, bssid, ssid, client_ip,
                     inside_geofence, distance_meters)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    $row['tenant_id'],
                    $row['branch_id'],
                    $row['employee_id'],
                    $row['bssid'] ?? null,
                    $row['ssid'] ?? null,
                    $row['client_ip'] ?? null,
                    !empty($row['inside_geofence']) ? 1 : 0,
                    $row['distance_meters'] ?? null,
                ]
            );
        } catch (Exception $e) {
            error_log('Network sighting failed: ' . $e->getMessage());
        }
    }

    /**
     * Distinct networks seen at a branch, with the counts the approval screen
     * needs to tell an office router apart from someone's home router.
     */
    public static function sightingsFor(int $branchId, int $tenantId, int $days = 14): array {
        $days = max(1, min(90, $days));

        return Database::fetchAll(
            "SELECT s.bssid,
                    MAX(s.ssid) AS ssid,
                    COUNT(*) AS sightings,
                    SUM(s.inside_geofence) AS inside_count,
                    COUNT(DISTINCT s.employee_id) AS employee_count,
                    MAX(s.seen_at) AS last_seen,
                    MAX(n.id IS NOT NULL AND n.is_active = 1) AS is_approved
             FROM branch_network_sightings s
             LEFT JOIN branch_networks n
                    ON n.tenant_id = s.tenant_id
                   AND n.branch_id = s.branch_id
                   AND n.kind = 'bssid'
                   AND n.value = s.bssid
             WHERE s.tenant_id = ? AND s.branch_id = ?
               AND s.bssid IS NOT NULL
               AND s.seen_at >= DATE_SUB(NOW(), INTERVAL {$days} DAY)
             GROUP BY s.bssid
             ORDER BY sightings DESC",
            [$tenantId, $branchId]
        );
    }

    /**
     * Total sightings in the window, used as the denominator for the coverage
     * percentage. Sightings with no BSSID (mobile data, iOS without the
     * entitlement) are excluded — they can never be "covered" by a BSSID list,
     * and counting them would understate the coverage and scare the admin off.
     */
    public static function sightingTotal(int $branchId, int $tenantId, int $days = 14): int {
        $days = max(1, min(90, $days));

        $row = Database::fetchOne(
            "SELECT COUNT(*) AS total
             FROM branch_network_sightings
             WHERE tenant_id = ? AND branch_id = ?
               AND bssid IS NOT NULL
               AND seen_at >= DATE_SUB(NOW(), INTERVAL {$days} DAY)",
            [$tenantId, $branchId]
        );

        return (int) ($row['total'] ?? 0);
    }

    /** Housekeeping for the attendance cron: sightings are short-lived data. */
    public static function purgeOldSightings(int $keepDays = 60): int {
        $keepDays = max(7, min(365, $keepDays));
        return Database::execute(
            "DELETE FROM branch_network_sightings
             WHERE seen_at < DATE_SUB(NOW(), INTERVAL {$keepDays} DAY)"
        );
    }
}
