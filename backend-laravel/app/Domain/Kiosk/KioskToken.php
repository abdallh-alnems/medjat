<?php

declare(strict_types=1);

namespace App\Domain\Kiosk;

use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * The credential a kiosk tablet presents on every request.
 *
 * Mirrors the employee token with one difference that matters more than it
 * looks: this resolves to a branch, never to a person. An employee token can
 * only record attendance for its owner; a kiosk token can record attendance for
 * anyone enrolled at its branch. That is why it is revocable from the
 * management app, why only the hash is stored, and why every lookup re-checks
 * that the station itself is still active.
 */
final class KioskToken
{
    public static function hash(string $plain): string
    {
        return hash('sha256', $plain);
    }

    /**
     * Resolves a presented token to its station.
     *
     * Joins the station rather than trusting the token row alone: revoking a
     * station and revoking its token are two writes, and a partially applied
     * revocation must fail closed.
     *
     * @return array<string, mixed>|null
     */
    public static function findActiveByPlain(string $plain): ?array
    {
        $row = DB::table('kiosk_auth_tokens as t')
            ->join('attendance_stations as s', 's.id', '=', 't.station_id')
            ->where('t.token_hash', self::hash($plain))
            ->whereNull('t.revoked_at')
            ->where('s.status', 'active')
            ->first([
                't.id', 't.tenant_id', 't.station_id', 't.device_id',
                's.branch_id', 's.name as station_name', 's.status as station_status', 's.app_version',
            ]);

        if ($row === null) {
            return null;
        }

        /** @var array<string, mixed> $columns */
        $columns = (array) $row;

        return $columns;
    }

    /**
     * Issues the station's token and returns the plaintext.
     *
     * The plaintext exists only in this return value and in the pairing
     * response. It is never stored, never logged, and cannot be recovered — a
     * database read must not hand anybody a working branch-wide credential.
     */
    public static function issueFor(int $tenantId, int $stationId, string $deviceId): string
    {
        // One live token per station: re-pairing the same tablet replaces the
        // old credential rather than leaving two valid ones behind.
        self::revokeForStation($stationId, 'replaced');

        $plain = bin2hex(random_bytes(32));

        DB::table('kiosk_auth_tokens')->insert([
            'tenant_id' => $tenantId,
            'station_id' => $stationId,
            'token_hash' => self::hash($plain),
            'device_id' => $deviceId,
        ]);

        return $plain;
    }

    /**
     * Revokes whatever live token the station holds.
     *
     * Stamped rather than deleted: the unique key on (station_id, revoked_at)
     * relies on MySQL treating NULLs as distinct, so revoked rows accumulate
     * harmlessly and the device history survives.
     */
    public static function revokeForStation(int $stationId, string $reason): void
    {
        DB::table('kiosk_auth_tokens')
            ->where('station_id', $stationId)->whereNull('revoked_at')
            ->update(['revoked_at' => DB::raw('NOW()'), 'revoke_reason' => $reason]);
    }

    public static function touchUsed(int $tokenId): void
    {
        DB::table('kiosk_auth_tokens')->where('id', $tokenId)
            ->update(['last_used_at' => DB::raw('NOW()')]);
    }

    public static function stationIdFor(string $plain): int
    {
        $active = self::findActiveByPlain($plain);

        return $active === null ? 0 : Value::int($active['station_id'] ?? null);
    }
}
