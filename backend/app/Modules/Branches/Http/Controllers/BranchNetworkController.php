<?php

declare(strict_types=1);

namespace App\Modules\Branches\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Http\Middleware\RequireBranchAccess;
use App\Models\Branch;
use App\Modules\Attendance\Domain\GeofenceCheck;
use App\Modules\Attendance\Domain\NetworkVerifier;
use App\Modules\Audit\Domain\AuditLog;
use App\Modules\Branches\Domain\Branches;
use App\Modules\Branches\Domain\BranchNetworks;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/branches/{capture_network,approve_networks,
 * network_sightings}.php.
 *
 * Teaching the system which networks mean "at this branch".
 *
 * The whole design assumes one router is several networks: a dual-band access
 * point broadcasts a separate address per band, plus one per guest network. So
 * capturing is the quick start and learning is the real answer — and the
 * coverage figure exists so an administrator can see what enforcement would do
 * before switching it on, rather than finding out from a queue of complaints
 * the next morning.
 */
final class BranchNetworkController
{
    public const WIFI_MODES = ['learning', 'enforcing', 'optional'];

    public const WIFI_MATCHES = ['bssid', 'ip', 'either'];

    /**
     * An administrator standing in the branch presses a button, and the access
     * point their phone is on is approved.
     *
     * The geofence guard is the important part: if they captured their home
     * router by mistake, that home would become the branch's valid location and
     * the office would be locked out.
     */
    public function capture(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = BranchController::admin($request);
        $branchId = BranchController::existing($request, $tenantId);
        RequireBranchAccess::assert($admin, $branchId);

        $bssid = NetworkVerifier::normaliseBssid($request->input('bssid'));

        if ($bssid === null) {
            // Also the path for an Android device with location switched off,
            // which reports a sentinel address rather than a real one.
            throw new ApiFailure(__('messages.wifi_not_connected'), 422, 'WIFI_NOT_CONNECTED');
        }

        $latitude = Value::float($request->input('latitude'));
        $longitude = Value::float($request->input('longitude'));

        if ($latitude === 0.0 && $longitude === 0.0) {
            throw new ApiFailure('Location is required to capture a branch network', 400, 'LOCATION_REQUIRED');
        }

        $branch = Branch::query()->where('id', $branchId)->where('tenant_id', $tenantId)->firstOrFail();
        $geofence = GeofenceCheck::evaluate($branch, $latitude, $longitude);

        if (! $geofence->passed) {
            throw new ApiFailure(__('messages.wifi_capture_outside_branch'), 403, 'CAPTURE_OUTSIDE_BRANCH', [
                'distance' => $geofence->distanceMetres,
                'allowed_radius' => $geofence->allowedRadiusMetres,
            ]);
        }

        $ssid = self::truncated($request->input('ssid'));
        $label = self::truncated($request->input('label'));

        BranchNetworks::approve($tenantId, $branchId, 'bssid', $bssid, $label ?? $ssid, 'captured', $admin->id);

        // A branch capturing its first network has clearly opted in, so it
        // starts in learning mode rather than being left unset — the remaining
        // access points still need discovering before enforcement makes sense.
        if (Value::nullableString($branch->getAttribute('wifi_mode')) === null) {
            Branches::updateWifiSettings(
                $branchId, $tenantId, 'learning',
                Value::string($branch->getAttribute('wifi_match'), 'bssid'),
            );
        }

        AuditLog::record($tenantId, $admin->id, 'branch.capture_network', 'branch', $branchId, [
            'bssid' => $bssid,
            'ssid' => $ssid,
        ]);

        return ApiResponse::success([
            'bssid' => $bssid,
            'ssid' => $ssid,
            'networks' => self::approved($branchId, $tenantId),
        ]);
    }

    /**
     * Approves a batch of networks, and optionally changes what enforcement
     * does with them.
     */
    public function approve(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = BranchController::admin($request);
        $branchId = BranchController::existing($request, $tenantId);
        RequireBranchAccess::assert($admin, $branchId);

        $approved = 0;
        $incoming = $request->input('approve', []);

        if (is_array($incoming)) {
            foreach ($incoming as $item) {
                if (! is_array($item)) {
                    continue;
                }

                [$kind, $value] = self::network($item);
                $label = self::truncated($item['label'] ?? null);
                $source = Value::string($item['source'] ?? null, 'discovered') ?: 'discovered';

                BranchNetworks::approve($tenantId, $branchId, $kind, $value, $label, $source, $admin->id);
                $approved++;
            }
        }

        $deactivated = 0;
        $toDeactivate = $request->input('deactivate');

        if (is_array($toDeactivate) && $toDeactivate !== []) {
            $deactivated = BranchNetworks::deactivate($tenantId, $branchId, array_values(array_map(
                static fn (mixed $id): int => Value::int($id),
                $toDeactivate,
            )));
        }

        if ($request->has('wifi_mode') || $request->has('wifi_match')) {
            $this->updateMode($request, $branchId, $tenantId);
        }

        AuditLog::record($tenantId, $admin->id, 'branch.approve_networks', 'branch', $branchId, [
            'approved' => $approved,
            'deactivated' => $deactivated,
            'wifi_mode' => $request->input('wifi_mode'),
        ]);

        return ApiResponse::success([
            'approved' => $approved,
            'deactivated' => $deactivated,
            'networks' => self::approved($branchId, $tenantId),
        ]);
    }

    /**
     * What was seen at the branch during the learning window.
     *
     * The coverage figure is the point: it answers "if I approve exactly these
     * and switch to enforcing, what share of last week's check-ins would still
     * pass?" before the switch is flipped.
     */
    public function sightings(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $admin = BranchController::admin($request);
        $branchId = BranchController::existing($request, $tenantId);
        RequireBranchAccess::assert($admin, $branchId);

        $branch = Branches::find($branchId, $tenantId) ?? [];
        $days = Value::int($request->input('days'), BranchNetworks::SIGHTING_WINDOW_DAYS);

        $rows = BranchNetworks::sightingsFor($branchId, $tenantId, $days);
        $total = BranchNetworks::sightingTotal($branchId, $tenantId, $days);

        $covered = 0;
        $networks = [];

        foreach ($rows as $row) {
            $sightings = Value::int($row['sightings'] ?? null);
            $inside = Value::int($row['inside_count'] ?? null);
            $isApproved = Value::int($row['is_approved'] ?? null) === 1;

            if ($isApproved) {
                $covered += $sightings;
            }

            $networks[] = [
                'bssid' => $row['bssid'] ?? null,
                'ssid' => $row['ssid'] ?? null,
                'sightings' => $sightings,
                'inside_count' => $inside,
                'outside_count' => $sightings - $inside,
                // A network only ever seen from outside the geofence is almost
                // always an employee's home router, caught during the week.
                'all_inside' => $inside === $sightings,
                'all_outside' => $inside === 0,
                'employee_count' => Value::int($row['employee_count'] ?? null),
                'last_seen' => $row['last_seen'] ?? null,
                'is_approved' => $isApproved,
            ];
        }

        return ApiResponse::success([
            'branch_id' => $branchId,
            'wifi_mode' => $branch['wifi_mode'] ?? null,
            'wifi_match' => Value::string($branch['wifi_match'] ?? null, 'bssid'),
            'days' => $days,
            'total_sightings' => $total,
            // The current-state baseline; the screen recomputes it live as
            // boxes are ticked.
            'coverage_percent' => $total > 0 ? round(($covered / $total) * 100, 1) : 0.0,
            'networks' => $networks,
        ]);
    }

    private function updateMode(Request $request, int $branchId, int $tenantId): void
    {
        $branch = Branches::find($branchId, $tenantId) ?? [];

        $mode = $request->has('wifi_mode')
            ? Value::nullableString($request->input('wifi_mode'))
            : Value::nullableString($branch['wifi_mode'] ?? null);

        if ($mode !== null && ! in_array($mode, self::WIFI_MODES, true)) {
            throw new ApiFailure('wifi_mode must be learning, enforcing or optional', 422, 'invalid_wifi_mode');
        }

        $match = $request->has('wifi_match')
            ? Value::string($request->input('wifi_match'))
            : Value::string($branch['wifi_match'] ?? null, 'bssid');

        if (! in_array($match, self::WIFI_MATCHES, true)) {
            throw new ApiFailure('wifi_match must be bssid, ip or either', 422, 'invalid_wifi_match');
        }

        // Enforcing with nothing approved would lock every employee out of the
        // branch on the next shift.
        if ($mode === 'enforcing' && ! self::hasApproved($branchId, $tenantId)) {
            throw new ApiFailure(
                'Approve at least one network before enabling enforcement',
                422,
                'no_approved_networks',
            );
        }

        Branches::updateWifiSettings($branchId, $tenantId, $mode, $match);
    }

    /**
     * @param  array<array-key, mixed>  $item
     * @return array{0: string, 1: string}
     */
    private static function network(array $item): array
    {
        $kind = Value::string($item['kind'] ?? null, 'bssid') ?: 'bssid';

        if (! in_array($kind, BranchNetworks::KINDS, true)) {
            throw new ApiFailure('Invalid network kind: '.$kind, 422, 'invalid_network_kind');
        }

        $value = Value::string($item['value'] ?? null);

        if ($kind === 'bssid') {
            $normalised = NetworkVerifier::normaliseBssid($value);

            if ($normalised === null) {
                throw new ApiFailure('Invalid BSSID: '.$value, 422, 'invalid_bssid');
            }

            return [$kind, $normalised];
        }

        if ($kind === 'ip_v4') {
            if (filter_var($value, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) === false) {
                throw new ApiFailure('Invalid IPv4 address: '.$value, 422, 'invalid_ip');
            }

            return [$kind, $value];
        }

        [$subnet, $bits] = array_pad(explode('/', $value, 2), 2, null);

        if (
            filter_var((string) $subnet, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) === false
            || $bits === null || ! ctype_digit($bits) || (int) $bits > 32
        ) {
            throw new ApiFailure('Invalid CIDR range: '.$value, 422, 'invalid_cidr');
        }

        return [$kind, $value];
    }

    /**
     * @return list<array<string, mixed>>
     */
    private static function approved(int $branchId, int $tenantId): array
    {
        $rows = DB::table('branch_networks')
            ->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('is_active', 1)
            ->get(['id', 'kind', 'value', 'label'])
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

    private static function hasApproved(int $branchId, int $tenantId): bool
    {
        return DB::table('branch_networks')
            ->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('is_active', 1)
            ->exists();
    }

    private static function truncated(mixed $raw): ?string
    {
        $value = trim(Value::string($raw));

        return $value === '' ? null : mb_substr($value, 0, 100);
    }
}
