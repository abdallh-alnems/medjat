<?php

declare(strict_types=1);

namespace App\Modules\Kiosk\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Models\Admin;
use App\Models\Branch;
use App\Modules\Kiosk\Domain\KioskPairing;
use App\Modules\Kiosk\Domain\KioskStation;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Ports of api/app/kiosk/{create_pairing_code,pair,create_access_code,open_admin,revoke}.php.
 *
 * Turning a tablet into a kiosk, opening its administration area, and taking it
 * out of service.
 */
final class PairingController
{
    /**
     * The plaintext code is returned here and nowhere else — only its hash is
     * stored, so re-reading the row cannot recover it. A kiosk credential can
     * record attendance for everyone at a branch, and a database read must not
     * hand anybody the means to create one.
     */
    public function createPairingCode(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $branch = self::branch(Value::int($request->input('branch_id')), $tenantId);

        // A tablet paired to a branch with the kiosk switched off would sit
        // there refusing everybody, which looks like broken hardware rather
        // than a setting.
        if (Value::int($branch->getAttribute('station_enabled')) !== 1) {
            throw new ApiFailure(__('messages.kiosk_pair_branch_disabled'), 422, 'kiosk_pair_branch_disabled');
        }

        $issued = KioskPairing::issuePairCode($tenantId, $branch->id, $adminId);

        return ApiResponse::success([
            'code' => $issued['code'],
            'expires_at' => $issued['expires_at'],
            'expires_in_seconds' => KioskPairing::PAIR_TTL_SECONDS,
            'branch' => ['id' => $branch->id, 'name' => $branch->name],
        ]);
    }

    /**
     * The only kiosk endpoint that accepts an unauthenticated request: the code
     * is the credential here, which is why it is single-use, short-lived, and
     * rate limited.
     *
     * Unknown, expired and already-consumed codes all answer the same way.
     * Distinguishing them would turn this into an oracle — an attacker could
     * tell a real-but-spent code from a wrong guess and learn the alphabet.
     */
    public function pair(Request $request): JsonResponse
    {
        $code = trim(Value::string($request->input('code')));
        $deviceId = trim(Value::string($request->input('device_id')));

        if ($code === '' || $deviceId === '') {
            throw new ApiFailure('code and device_id are required', 422, 'missing_fields');
        }

        $codeRow = KioskPairing::consume($code, 'pair');

        if ($codeRow === null) {
            throw new ApiFailure(__('messages.kiosk_pair_code_spent'), 410, 'kiosk_pair_code_spent');
        }

        $tenantId = Value::int($codeRow['tenant_id'] ?? null);
        $branch = Branch::query()
            ->where('id', Value::int($codeRow['branch_id'] ?? null))->where('tenant_id', $tenantId)
            ->first();

        if ($branch === null) {
            // The branch was deleted between issuing the code and redeeming it.
            throw new ApiFailure(__('messages.kiosk_pair_branch_disabled'), 422, 'kiosk_pair_branch_disabled');
        }

        $name = trim(Value::string($request->input('name')));
        $name = $name !== '' ? substr($name, 0, 100) : null;

        $paired = KioskPairing::pairDevice(
            $codeRow,
            $deviceId,
            self::truncated($request->input('device_model'), 100),
            Value::string($request->input('platform')) === 'ios' ? 'ios' : 'android',
            self::truncated($request->input('app_version'), 20),
            $name ?? $branch->name,
        );

        $tenant = DB::table('tenants')->where('id', $tenantId)->first(['name', 'timezone']);

        // The branch name goes back so the tablet can confirm on screen what it
        // has become: a supervisor pairing five devices needs to see which is
        // which before mounting them on walls.
        return ApiResponse::success([
            'kiosk_token' => $paired['token'],
            'station' => ['id' => $paired['station_id'], 'name' => $name ?? $branch->name],
            'branch' => [
                'id' => $branch->id,
                'name' => $branch->name,
                'latitude' => self::float($branch->getAttribute('latitude')),
                'longitude' => self::float($branch->getAttribute('longitude')),
                'station_gps_radius_meters' => Value::int($branch->getAttribute('station_gps_radius_meters'), 30),
            ],
            'tenant' => [
                'id' => $tenantId,
                'name' => $tenant?->name,
                'timezone' => Value::string($tenant?->timezone, 'Africa/Cairo'),
            ],
        ]);
    }

    /**
     * Issuing one of these is a daily task for a branch manager; pairing and
     * unpairing hardware is not. Somebody who can enrol a face should not
     * thereby be able to unpair the fleet, which is why this costs a different
     * permission from the pairing code.
     */
    public function createAccessCode(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $stationId = Value::int($request->input('station_id'));

        $station = KioskStation::find($stationId, $tenantId);

        if ($station === null) {
            throw new ApiFailure('Kiosk not found', 404, 'not_found');
        }

        if (Value::string($station['status'] ?? null) !== 'active') {
            throw new ApiFailure(__('messages.kiosk_token_invalid'), 409, 'kiosk_revoked');
        }

        $issued = KioskPairing::issueAccessCode(
            $tenantId, Value::int($station['branch_id'] ?? null), $stationId, $adminId
        );

        return ApiResponse::success([
            'code' => $issued['code'],
            'expires_at' => $issued['expires_at'],
            'expires_in_seconds' => KioskPairing::ACCESS_TTL_SECONDS,
            'station' => ['id' => $stationId, 'name' => $station['name'] ?? null],
        ]);
    }

    /**
     * The code must belong to this station. An access code generated for the
     * tablet at one branch must not open the tablet at another, or a supervisor
     * with access to a quiet branch could enrol faces on a busy one.
     */
    public function openAdmin(Request $request): JsonResponse
    {
        $stationId = Value::int($request->attributes->get('station_id'));
        $code = trim(Value::string($request->input('code')));

        if ($code === '') {
            throw new ApiFailure('code is required', 422, 'code_required');
        }

        $codeRow = KioskPairing::consume($code, 'access', $stationId);

        // Unknown, expired and already-spent answer alike: distinguishing them
        // would let somebody probing six digits tell a real code from a wrong
        // one.
        if ($codeRow === null || Value::int($codeRow['station_id'] ?? null) !== $stationId) {
            throw new ApiFailure(__('messages.kiosk_pair_code_spent'), 410, 'kiosk_pair_code_spent');
        }

        $authorisedBy = Value::int($codeRow['created_by'] ?? null);
        $session = KioskPairing::openAdminSession($stationId, $authorisedBy);

        return ApiResponse::success([
            'admin_session' => $session,
            'expires_in_seconds' => KioskPairing::ADMIN_SESSION_TTL_SECONDS,
            // Carried onto every enrollment made in this session: the audit
            // trail names the administrator who authorised it, not the tablet.
            'authorised_by' => [
                'id' => $authorisedBy,
                'name' => DB::table('admins')->where('id', $authorisedBy)->value('name'),
            ],
        ]);
    }

    /**
     * Effective on the tablet's next request, which is the honest guarantee: a
     * device that is switched off cannot be told anything. That is enough for
     * the case this exists for — a stolen tablet is useless the moment it next
     * reaches the network.
     */
    public function revoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $adminId = self::admin($request)->id;
        $stationId = Value::int($request->input('station_id'));

        $station = KioskStation::find($stationId, $tenantId);

        if ($station === null) {
            throw new ApiFailure('Kiosk not found', 404, 'not_found');
        }

        if (Value::string($station['status'] ?? null) === 'revoked') {
            // Idempotent: revoking twice is a supervisor tapping again.
            return ApiResponse::success([
                'station_id' => $stationId,
                'status' => 'revoked',
                'revoked_at' => $station['revoked_at'] ?? null,
                'already_revoked' => true,
            ]);
        }

        if (! KioskStation::revoke($stationId, $tenantId, $adminId)) {
            throw new ApiFailure('Could not revoke this kiosk', 409, 'kiosk_revoke_failed');
        }

        return ApiResponse::success([
            'station_id' => $stationId,
            'status' => 'revoked',
            'already_revoked' => false,
        ]);
    }

    private static function branch(int $branchId, int $tenantId): Branch
    {
        if ($branchId <= 0) {
            throw new ApiFailure('branch_id is required', 422, 'branch_id_required');
        }

        $branch = Branch::query()->where('id', $branchId)->where('tenant_id', $tenantId)->first();

        if ($branch === null) {
            throw new ApiFailure('Branch not found', 404, 'not_found');
        }

        return $branch;
    }

    private static function admin(Request $request): Admin
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        return $admin;
    }

    private static function truncated(mixed $raw, int $length): ?string
    {
        $value = Value::string($raw);

        return $value === '' ? null : substr($value, 0, $length);
    }

    private static function float(mixed $raw): ?float
    {
        return is_numeric($raw) ? (float) $raw : null;
    }
}
