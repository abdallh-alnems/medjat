<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Domain;

use App\Models\Branch;
use App\Support\Value;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Request;

/**
 * The network constraint on a punch.
 *
 * WiFi is a constraint on top of the geofence, never a substitute for it: GPS
 * drifts indoors and the signal leaks outdoors, so either one alone is wrong in
 * a different direction.
 *
 * Every mode fails open where it cannot decide. Learning mode never rejects
 * because the branch is still discovering its own access points, and a branch
 * enforcing with nothing matchable is a misconfiguration rather than a reason to
 * lock out its staff.
 */
final class NetworkVerifier
{
    /** Android returns this when location permission is denied, for every AP. */
    private const ANDROID_DENIED_BSSID = '02:00:00:00:00:00';

    /**
     * What the browser page may be told about this branch: 'ip' when a refusal
     * is actually possible, 'none' when nothing on this channel can be checked.
     *
     * Shares acceptsBrowser()'s conditions on purpose. A status endpoint that
     * announces a control the punch path never applies is exactly the drift this
     * pair exists to prevent — it shipped that way once already.
     */
    public static function browserConstraint(Branch $branch): string
    {
        $mode = Value::nullableString($branch->wifi_mode);

        if ($mode === null || $mode === 'learning' || $mode === 'optional') {
            return 'none';
        }

        return self::ipNetworks($branch) === [] ? 'none' : 'ip';
    }

    /**
     * The browser channel's check.
     *
     * A page cannot read the access point it is joined to, so a branch whose
     * WiFi control is entirely BSSID-based has no network constraint here at all
     * — even though its app attendance looks well guarded. Only IP-shaped rows
     * can hold a browser to anything.
     */
    public static function acceptsBrowser(Branch $branch): bool
    {
        $mode = Value::nullableString($branch->wifi_mode);

        if ($mode === null || $mode === 'learning') {
            return true;
        }

        $networks = self::ipNetworks($branch);
        if ($networks === []) {
            return true;
        }

        $ip = Request::ip();
        if ($ip !== null && self::ipMatches($ip, $networks)) {
            return true;
        }

        // 'optional' covers employees on mobile data, on every channel.
        return $mode === 'optional';
    }

    /**
     * The phone channel's check, where a BSSID is available.
     *
     * @param  array<array-key, mixed>  $input
     * @return array{accepted: bool, reason: string}
     */
    public static function acceptsApp(Branch $branch, array $input): array
    {
        $mode = Value::nullableString($branch->wifi_mode);

        if ($mode === null || $mode === 'learning') {
            return ['accepted' => true, 'reason' => 'learning'];
        }

        $networks = self::approved($branch);
        if ($networks === []) {
            return ['accepted' => true, 'reason' => 'no_networks'];
        }

        $bssid = self::normaliseBssid($input['wifi_bssid'] ?? null);
        if ($bssid !== null && self::bssidMatches($bssid, $networks)) {
            return ['accepted' => true, 'reason' => 'matched'];
        }

        $ip = Request::ip();
        if ($ip !== null && self::ipMatches($ip, self::onlyIp($networks))) {
            return ['accepted' => true, 'reason' => 'matched_ip'];
        }

        if ($mode === 'optional') {
            return ['accepted' => true, 'reason' => 'optional_gps_fallback'];
        }

        return ['accepted' => false, 'reason' => 'wrong_network'];
    }

    /**
     * Records that this network was seen at this branch.
     *
     * Written before the GPS verdict and regardless of it: "someone tried from
     * outside the fence on network X" is exactly the signal the approval screen
     * needs to keep an employee's home router out of the branch's list.
     *
     * @param  array<array-key, mixed>  $input
     */
    public static function recordSighting(
        int $tenantId,
        int $branchId,
        int $employeeId,
        array $input,
        bool $insideGeofence,
        ?float $distanceMetres = null,
    ): void {
        $ssid = mb_substr(Value::string($input['wifi_ssid'] ?? null), 0, 100);

        DB::table('branch_network_sightings')->insert([
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'employee_id' => $employeeId,
            'bssid' => self::normaliseBssid($input['wifi_bssid'] ?? null),
            'ssid' => $ssid !== '' ? $ssid : null,
            'client_ip' => Request::ip(),
            'inside_geofence' => $insideGeofence ? 1 : 0,
            'distance_meters' => $distanceMetres === null ? null : (int) round($distanceMetres),
        ]);
    }

    /**
     * A BSSID in a comparable form, or null when there is nothing usable.
     *
     * Android reports 02:00:00:00:00:00 for every access point when location
     * permission is denied, so that value means "the phone would not say",
     * not "this network". Treating it as an identifier would let one denied
     * permission match every branch.
     */
    public static function normaliseBssid(mixed $raw): ?string
    {
        if (! is_string($raw) || $raw === '') {
            return null;
        }

        $bssid = mb_strtolower(trim($raw));

        if ($bssid === self::ANDROID_DENIED_BSSID) {
            return null;
        }

        return preg_match('/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/', $bssid) === 1 ? $bssid : null;
    }

    /**
     * @return list<array{kind: string, value: string}>
     */
    private static function approved(Branch $branch): array
    {
        $rows = DB::table('branch_networks')
            ->where('tenant_id', $branch->tenant_id)
            ->where('branch_id', $branch->id)
            ->where('is_active', 1)
            ->get(['kind', 'value']);

        $networks = [];
        foreach ($rows as $row) {
            $kind = Value::string($row->kind);
            $value = Value::string($row->value);
            if ($kind !== '' && $value !== '') {
                $networks[] = ['kind' => $kind, 'value' => $value];
            }
        }

        return $networks;
    }

    /**
     * @return list<array{kind: string, value: string}>
     */
    private static function ipNetworks(Branch $branch): array
    {
        return self::onlyIp(self::approved($branch));
    }

    /**
     * @param  list<array{kind: string, value: string}>  $networks
     * @return list<array{kind: string, value: string}>
     */
    private static function onlyIp(array $networks): array
    {
        return array_values(array_filter(
            $networks,
            static fn (array $n): bool => $n['kind'] === 'ip_v4' || $n['kind'] === 'ip_cidr',
        ));
    }

    /**
     * @param  list<array{kind: string, value: string}>  $networks
     */
    private static function bssidMatches(string $bssid, array $networks): bool
    {
        foreach ($networks as $network) {
            if ($network['kind'] === 'bssid' && $network['value'] === $bssid) {
                return true;
            }
        }

        return false;
    }

    /**
     * @param  list<array{kind: string, value: string}>  $networks
     */
    private static function ipMatches(string $ip, array $networks): bool
    {
        foreach ($networks as $network) {
            if ($network['kind'] === 'ip_v4' && $network['value'] === $ip) {
                return true;
            }

            if ($network['kind'] === 'ip_cidr' && self::inCidr($ip, $network['value'])) {
                return true;
            }
        }

        return false;
    }

    private static function inCidr(string $ip, string $cidr): bool
    {
        if (! str_contains($cidr, '/')) {
            return false;
        }

        [$subnet, $bits] = explode('/', $cidr, 2);
        $prefix = (int) $bits;

        if ($prefix < 0 || $prefix > 32) {
            return false;
        }

        $ipLong = ip2long($ip);
        $subnetLong = ip2long($subnet);

        if ($ipLong === false || $subnetLong === false) {
            return false;
        }

        // A /0 shifted by 32 is undefined behaviour in PHP, so it is handled
        // as what it means: everything matches.
        if ($prefix === 0) {
            return true;
        }

        $mask = -1 << (32 - $prefix);

        return ($ipLong & $mask) === ($subnetLong & $mask);
    }
}
