<?php

declare(strict_types=1);

namespace App\Modules\Kiosk\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Branch;
use App\Modules\Kiosk\Domain\KioskStation;
use App\Shared\Face\FaceEmbedding;
use App\Shared\Face\FaceMatcher;
use App\Shared\Http\ApiResponse;
use App\Shared\RemoteConfig\RemoteConfigGate;
use App\Shared\Time\TenantClock;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/kiosk/{heartbeat,challenge}.php.
 *
 * The tablet reporting in, and the nonce it needs before a capture.
 */
final class KioskSessionController
{
    public function __construct(
        private readonly FaceMatcher $faces,
        private readonly RemoteConfigGate $gate,
    ) {}

    /**
     * The single point where every "stop serving employees" condition takes
     * effect, which is why the kiosk calls it on launch and periodically after.
     *
     * Three conditions stop it serving employees, and each answers with a
     * status the tablet routes on: 401 the token was revoked or the station
     * unpaired, 426 this build is below the minimum, 503 maintenance is on.
     *
     * A revoked tablet cannot be told anything while it is switched off, so
     * revocation is honest about being effective on the device's next contact —
     * which is here.
     */
    public function heartbeat(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $branchId = Value::int($request->attributes->get('branch_id'));
        $stationId = Value::int($request->attributes->get('station_id'));
        $kiosk = $request->attributes->get('kiosk');

        $appVersion = Value::string($request->input('app_version'))
            ?: Value::string(is_array($kiosk) ? ($kiosk['app_version'] ?? null) : null, '0.0.0');

        // Cached and fail-open: a configuration outage must not stop every
        // kiosk in every company from recording attendance.
        $gate = $this->gate->forApp('permedjat_kiosk');

        if ($gate->maintenance) {
            throw new ApiFailure(__('messages.kiosk_maintenance'), 503, 'kiosk_maintenance');
        }

        if ($gate->isBelowMinimum($appVersion)) {
            // Addressed to a supervisor, not to the employee standing at the
            // door: a directly-installed kiosk has no store to send anybody to.
            throw new ApiFailure(
                __('messages.kiosk_update_required'),
                426,
                'kiosk_update_required',
                ['min_version' => $gate->minVersion, 'current_version' => $appVersion],
            );
        }

        $branch = Branch::query()->where('id', $branchId)->where('tenant_id', $tenantId)->first();

        if ($branch === null) {
            // The branch was deleted underneath a live kiosk. Revoking rather
            // than erroring keeps a tablet from retrying against nothing.
            KioskStation::revoke($stationId, $tenantId, null);

            throw new ApiFailure(__('messages.kiosk_token_invalid'), 401, 'kiosk_token_invalid');
        }

        if (Value::int($branch->getAttribute('station_enabled')) !== 1) {
            throw new ApiFailure(__('messages.kiosk_pair_branch_disabled'), 403, 'kiosk_pair_branch_disabled');
        }

        $faceSettings = $this->faces->settingsFor($branch, $tenantId);
        $stationName = is_array($kiosk) ? ($kiosk['station_name'] ?? null) : null;

        return ApiResponse::success([
            'station_status' => 'active',
            'station' => ['id' => $stationId, 'name' => $stationName],
            'branch' => ['id' => $branch->id, 'name' => $branch->name],
            // Company time. A cheap tablet with no SIM keeps a wrong clock, and
            // the kiosk must never render its own.
            'server_time' => TenantClock::now($tenantId)->format(DATE_ATOM),
            'settings' => [
                'code_fallback_enabled' => Value::int($branch->getAttribute('station_code_fallback_enabled'), 1) === 1,
                'anti_spoofing_enabled' => Value::int($branch->getAttribute('station_anti_spoofing_enabled'), 1) === 1,
                'liveness_required' => $faceSettings['liveness_required'],
                'gps_radius_meters' => Value::int($branch->getAttribute('station_gps_radius_meters'), 30),
                'branch_latitude' => self::float($branch->getAttribute('latitude')),
                'branch_longitude' => self::float($branch->getAttribute('longitude')),
                'min_seconds_between_punches' => 60,
            ],
        ]);
    }

    /**
     * A single-use nonce and the liveness action to perform.
     *
     * Issued with no employee attached — the whole point of a kiosk is that
     * nobody has said who they are yet.
     */
    public function challenge(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $purpose = Value::string($request->input('purpose')) === 'enroll' ? 'enroll' : 'check_in';

        $challenge = FaceMatcher::CHALLENGES[array_rand(FaceMatcher::CHALLENGES)];
        $nonce = bin2hex(random_bytes(32));

        DB::insert(
            'INSERT INTO face_challenges (tenant_id, employee_id, nonce, challenge, purpose, expires_at)'
            .' VALUES (?, NULL, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 60 SECOND))',
            [$tenantId, $nonce, $challenge, $purpose],
        );

        return ApiResponse::success([
            'nonce' => $nonce,
            'challenge' => $challenge,
            'expires_in_seconds' => 60,
            'model_version' => FaceEmbedding::MODEL_VERSION,
        ]);
    }

    private static function float(mixed $raw): ?float
    {
        return is_numeric($raw) ? (float) $raw : null;
    }
}
