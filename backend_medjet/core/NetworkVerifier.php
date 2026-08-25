<?php

/**
 * WiFi-network verification for the `wifi_gps` attendance method.
 *
 * The employee must be connected to one of the branch's approved access points
 * (or coming from an approved public IP). This runs IN ADDITION to the GPS
 * geofence, never instead of it:
 *
 *   - GPS alone is weak indoors — it drifts 50-100m inside a concrete building,
 *     which is wider than the default 100m branch radius.
 *   - WiFi alone leaks outside — the signal reaches the car park and the floor
 *     below.
 *
 * Together they cover each other's blind spot. Neither proves WHO is holding
 * the phone; that is face_selfie's job.
 */
final class NetworkVerifier {
    /**
     * Android returns this sentinel instead of a real BSSID when location
     * permission is missing or location services are switched off. It is not a
     * network — treating it as one would let every such device match a single
     * bogus "approved" entry.
     */
    private const ANDROID_DENIED_BSSID = '02:00:00:00:00:00';

    /** Sightings older than this are not shown on the approval screen. */
    public const SIGHTING_WINDOW_DAYS = 14;

    /**
     * Normalises a BSSID to lower-case colon form, or null if it isn't one.
     * Accepts the colon and dash separators phones report interchangeably.
     */
    public static function normaliseBssid($raw): ?string {
        if (!is_string($raw)) {
            return null;
        }
        $value = strtolower(trim($raw));
        if ($value === '') {
            return null;
        }

        $value = str_replace('-', ':', $value);
        if (!preg_match('/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/', $value)) {
            return null;
        }

        // Permission-denied sentinel and the all-zero placeholder are not
        // networks; the caller must treat them as "not on WiFi".
        if ($value === self::ANDROID_DENIED_BSSID || $value === '00:00:00:00:00:00') {
            return null;
        }

        return $value;
    }

    /** The real client IP. nginx already maps CF-Connecting-IP onto REMOTE_ADDR. */
    public static function clientIp(): ?string {
        $ip = $_SERVER['REMOTE_ADDR'] ?? null;
        return is_string($ip) && filter_var($ip, FILTER_VALIDATE_IP) ? $ip : null;
    }

    /** True when the IP falls inside an approved address or CIDR range. */
    private static function ipMatches(string $ip, array $networks): bool {
        foreach ($networks as $network) {
            if ($network['kind'] === 'ip_v4' && $network['value'] === $ip) {
                return true;
            }
            if ($network['kind'] === 'ip_cidr' && self::ipInCidr($ip, $network['value'])) {
                return true;
            }
        }
        return false;
    }

    private static function ipInCidr(string $ip, string $cidr): bool {
        if (!str_contains($cidr, '/')) {
            return false;
        }
        [$subnet, $bits] = explode('/', $cidr, 2);
        $bits = (int) $bits;
        if ($bits < 0 || $bits > 32) {
            return false;
        }

        $ipLong = ip2long($ip);
        $subnetLong = ip2long($subnet);
        if ($ipLong === false || $subnetLong === false) {
            return false;
        }

        // A /0 mask would shift by 32, which is undefined on 32-bit ints.
        $mask = $bits === 0 ? 0 : (-1 << (32 - $bits));
        return ($ipLong & $mask) === ($subnetLong & $mask);
    }

    /**
     * Records what the device reported, whatever the outcome.
     *
     * Called even when GPS has already rejected the check-in: "someone tried
     * from outside the geofence on network X" is precisely the signal the
     * approval screen needs to keep a home router out of the approved list.
     */
    public static function recordSighting(
        int $tenantId,
        int $branchId,
        int $employeeId,
        array $input,
        bool $insideGeofence,
        ?float $distanceMeters
    ): void {
        $bssid = self::normaliseBssid($input['wifi_bssid'] ?? null);
        $ssid = isset($input['wifi_ssid']) ? mb_substr((string) $input['wifi_ssid'], 0, 100) : null;

        BranchNetworkModel::recordSighting([
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'employee_id' => $employeeId,
            'bssid' => $bssid,
            'ssid' => $ssid !== '' ? $ssid : null,
            'client_ip' => self::clientIp(),
            'inside_geofence' => $insideGeofence,
            'distance_meters' => $distanceMeters !== null ? (int) round($distanceMeters) : null,
        ]);
    }

    /**
     * Decides whether the reported network is acceptable for this branch.
     *
     * @return array{accepted: bool, reason: string, message: string}
     */
    public static function verify(array $branch, array $input): array {
        $mode = $branch['wifi_mode'] ?? null;

        // Learning mode never rejects: the branch is still collecting the list
        // of its own access points. Enforcing before anything is approved would
        // lock the whole company out on day one.
        if ($mode === null || $mode === 'learning') {
            return self::ok('learning');
        }

        $tenantId = (int) $branch['tenant_id'];
        $branchId = (int) $branch['id'];
        $networks = BranchNetworkModel::approvedFor($branchId, $tenantId);

        // Enforcing with an empty approved list is a misconfiguration, not a
        // reason to reject everyone. Fail open and let the admin notice via the
        // approval screen rather than via a company-wide outage.
        if (empty($networks)) {
            return self::ok('no_networks_configured');
        }

        $match = $branch['wifi_match'] ?? 'bssid';
        $bssid = self::normaliseBssid($input['wifi_bssid'] ?? null);
        $ip = self::clientIp();

        $bssidOk = $bssid !== null && self::bssidMatches($bssid, $networks);
        $ipOk = $ip !== null && self::ipMatches($ip, $networks);

        $accepted = match ($match) {
            'ip' => $ipOk,
            'either' => $bssidOk || $ipOk,
            default => $bssidOk,
        };

        if ($accepted) {
            return self::ok('matched');
        }

        // `optional` accepts a GPS-only check-in, so a device with no WiFi at
        // all still passes — it is there to cover employees on mobile data.
        if ($mode === 'optional') {
            return self::ok('optional_gps_fallback');
        }

        // Distinguish "not connected to WiFi" from "connected to the wrong
        // network". Telling an employee on mobile data that their network is
        // unauthorised sends them hunting for a problem that isn't there.
        $onWifi = $bssid !== null;
        return [
            'accepted' => false,
            'reason' => $onWifi ? 'wrong_network' : 'not_on_wifi',
            'message' => $onWifi
                ? I18n::t('wifi_wrong_network')
                : I18n::t('wifi_not_connected'),
        ];
    }

    /**
     * The network check for the browser channel.
     *
     * Deliberately NOT a flag inside verify(). The two channels can produce
     * different evidence, and merging them would lock the browser out rather
     * than constrain it: `wifi_match` defaults to 'bssid' and a web page can
     * never report a BSSID, so verify() would refuse every browser punch at any
     * branch that enforces — an outage dressed as a security control.
     *
     * Only the IP-shaped rows are reachable from a browser, so only those are
     * applied. A branch whose approved list is entirely BSSIDs therefore has no
     * network control at all on this channel; that is reported honestly by
     * browserConstraint() instead of being pretended into existence here.
     *
     * @return array{accepted: bool, reason: string, message: string}
     */
    public static function verifyBrowser(array $branch): array {
        $mode = $branch['wifi_mode'] ?? null;

        // Same order of mercy as verify(): learning never rejects, because the
        // branch is still collecting its own access points.
        if ($mode === null || $mode === 'learning') {
            return self::ok('learning');
        }

        $networks = self::ipNetworksFor($branch);

        // Enforcing with nothing a browser could match is a misconfiguration,
        // not a reason to reject everyone. Fails open, exactly as verify() does
        // with an empty approved list.
        if ($networks === []) {
            return self::ok('no_ip_networks');
        }

        $ip = self::clientIp();
        if ($ip !== null && self::ipMatches($ip, $networks)) {
            return self::ok('matched');
        }

        // `optional` covers employees on mobile data, on every channel.
        if ($mode === 'optional') {
            return self::ok('optional_gps_fallback');
        }

        return [
            'accepted' => false,
            'reason' => 'web_wrong_network',
            'message' => I18n::t('web_wrong_network'),
        ];
    }

    /**
     * What the browser page may be told about this branch: 'ip' when a refusal
     * is actually possible, 'none' when nothing on this channel can be checked.
     *
     * Shares verifyBrowser()'s conditions on purpose. A status endpoint that
     * announces a control the punch path never applies is precisely the drift
     * this pair exists to prevent — it shipped that way once already.
     */
    public static function browserConstraint(array $branch): string {
        $mode = $branch['wifi_mode'] ?? null;
        if ($mode === null || $mode === 'learning' || $mode === 'optional') {
            return 'none';
        }
        return self::ipNetworksFor($branch) === [] ? 'none' : 'ip';
    }

    /** Approved rows a browser could possibly match — the IP-shaped ones. */
    private static function ipNetworksFor(array $branch): array {
        $networks = BranchNetworkModel::approvedFor(
            (int) $branch['id'],
            (int) $branch['tenant_id']
        );
        return array_values(array_filter(
            $networks,
            static fn($n) => $n['kind'] === 'ip_v4' || $n['kind'] === 'ip_cidr'
        ));
    }

    private static function bssidMatches(string $bssid, array $networks): bool {
        foreach ($networks as $network) {
            if ($network['kind'] === 'bssid' && $network['value'] === $bssid) {
                return true;
            }
        }
        return false;
    }

    private static function ok(string $reason): array {
        return ['accepted' => true, 'reason' => $reason, 'message' => ''];
    }
}
