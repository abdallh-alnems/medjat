<?php

declare(strict_types=1);

namespace App\Modules\Kiosk\Domain;

use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * The two short-lived secrets a kiosk lives by.
 *
 *   pair   — turns an unconfigured tablet into a station bound to one branch.
 *   access — opens the administration area of a tablet already in service:
 *            enrollment, settings, and release of kiosk mode.
 *
 * Both are single-use, short-lived, and stored hashed. The hashing is the one
 * place this differs from employee activation codes, which keep their code in
 * plaintext: an access code enrols faces and unlocks the tablet, so a database
 * read must not hand anybody a working key.
 *
 * Every expiry is computed in SQL. PHP runs UTC while MySQL runs the server
 * zone; a PHP-computed expiry is born hours wrong, which the face challenge
 * table already learned the hard way.
 */
final class KioskPairing
{
    /** Long enough to walk to the tablet and type it; short enough to be useless if overheard. */
    public const PAIR_TTL_SECONDS = 900;

    /** Shorter: a supervisor reads it off a phone and types it immediately. */
    public const ACCESS_TTL_SECONDS = 300;

    /** Ten minutes of enrolling, refreshed by activity. */
    public const ADMIN_SESSION_TTL_SECONDS = 600;

    /**
     * Human-typed on a tablet, so the alphabet excludes the characters people
     * confuse: 0/O and 1/I/L.
     */
    private const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

    public static function hash(string $plain): string
    {
        return hash('sha256', strtoupper(trim($plain)));
    }

    /**
     * @return array{code: string, expires_at: string}
     */
    public static function issuePairCode(int $tenantId, int $branchId, int $createdBy): array
    {
        $code = self::generateCode(8);
        $hash = self::hash($code);

        DB::insert(
            'INSERT INTO kiosk_codes (tenant_id, branch_id, station_id, purpose, code_hash, expires_at, created_by)'
            ." VALUES (?, ?, NULL, 'pair', ?, DATE_ADD(NOW(), INTERVAL ? SECOND), ?)",
            [$tenantId, $branchId, $hash, self::PAIR_TTL_SECONDS, $createdBy],
        );

        return ['code' => $code, 'expires_at' => self::expiryOf($hash)];
    }

    /**
     * Digits only: this one is typed far more often than a pairing code, often
     * by someone holding a phone in the other hand.
     *
     * @return array{code: string, expires_at: string}
     */
    public static function issueAccessCode(int $tenantId, int $branchId, int $stationId, int $createdBy): array
    {
        $code = self::generateDigits(6);
        $hash = self::hash($code);

        DB::insert(
            'INSERT INTO kiosk_codes (tenant_id, branch_id, station_id, purpose, code_hash, expires_at, created_by)'
            ." VALUES (?, ?, ?, 'access', ?, DATE_ADD(NOW(), INTERVAL ? SECOND), ?)",
            [$tenantId, $branchId, $stationId, $hash, self::ACCESS_TTL_SECONDS, $createdBy],
        );

        return ['code' => $code, 'expires_at' => self::expiryOf($hash)];
    }

    /**
     * Consumes a code, atomically.
     *
     * The lookup, the expiry check and the used-at write are one guarded UPDATE
     * rather than a read followed by a write. Two tablets racing the same code
     * is not hypothetical — a supervisor pairing several devices will type the
     * same code twice by accident — and a read-then-write would let both
     * through.
     *
     * Zero affected rows means unknown, expired, or already consumed. Callers
     * must not distinguish those three: an endpoint that says "expired" rather
     * than "unknown" is an oracle for guessing codes.
     *
     * @return array<string, mixed>|null
     */
    public static function consume(string $plainCode, string $purpose, ?int $stationId = null): ?array
    {
        $hash = self::hash($plainCode);

        $affected = DB::update(
            'UPDATE kiosk_codes SET used_at = NOW(), used_by_station = ?'
            .' WHERE code_hash = ? AND purpose = ? AND used_at IS NULL AND expires_at > NOW()',
            [$stationId, $hash, $purpose],
        );

        if ($affected === 0) {
            return null;
        }

        $row = DB::table('kiosk_codes')
            ->where('code_hash', $hash)->where('purpose', $purpose)
            ->orderByDesc('id')
            ->first();

        return $row === null ? null : self::toArray($row);
    }

    /**
     * Pairs a tablet: creates the station and issues its credential.
     *
     * @param  array<string, mixed>  $code
     * @return array{station_id: int, token: string}
     */
    public static function pairDevice(
        array $code,
        string $deviceId,
        ?string $deviceModel,
        string $platform,
        ?string $appVersion,
        ?string $name,
    ): array {
        $stationId = KioskStation::create(
            Value::int($code['tenant_id'] ?? null),
            Value::int($code['branch_id'] ?? null),
            $name,
            $deviceModel,
            $platform,
            $appVersion,
            Value::int($code['created_by'] ?? null),
        );

        // Record which station consumed the code, now that one exists. The
        // guarded UPDATE could not do this: the station is created here.
        DB::table('kiosk_codes')->where('id', Value::int($code['id'] ?? null))
            ->update(['used_by_station' => $stationId]);

        $token = KioskToken::issueFor(Value::int($code['tenant_id'] ?? null), $stationId, $deviceId);

        return ['station_id' => $stationId, 'token' => $token];
    }

    /**
     * Opens the administration area on a station.
     *
     * Stored hashed on the station row: exactly one session per tablet, because
     * a tablet has exactly one administration area. Returns the plaintext once.
     */
    public static function openAdminSession(int $stationId, int $authorisedBy): string
    {
        $plain = bin2hex(random_bytes(32));

        DB::update(
            'UPDATE attendance_stations'
            .' SET admin_session_hash = ?, admin_session_expires_at = DATE_ADD(NOW(), INTERVAL ? SECOND),'
            .' admin_session_by = ? WHERE id = ?',
            [hash('sha256', $plain), self::ADMIN_SESSION_TTL_SECONDS, $authorisedBy, $stationId],
        );

        return $plain;
    }

    /**
     * Validates an admin session and extends it.
     *
     * Refreshing on every call is what lets a supervisor work through a queue of
     * thirty people without being thrown out mid-enrollment, while an abandoned
     * screen still closes itself within the window.
     *
     * @return array<string, mixed>|null
     */
    public static function touchAdminSession(int $stationId, string $plain): ?array
    {
        if ($plain === '') {
            return null;
        }

        $station = DB::selectOne(
            'SELECT * FROM attendance_stations'
            .' WHERE id = ? AND admin_session_hash = ? AND admin_session_expires_at > NOW() LIMIT 1',
            [$stationId, hash('sha256', $plain)],
        );

        if ($station === null) {
            return null;
        }

        DB::update(
            'UPDATE attendance_stations SET admin_session_expires_at = DATE_ADD(NOW(), INTERVAL ? SECOND) WHERE id = ?',
            [self::ADMIN_SESSION_TTL_SECONDS, $stationId],
        );

        return self::toArray($station);
    }

    public static function closeAdminSession(int $stationId): void
    {
        DB::table('attendance_stations')->where('id', $stationId)->update([
            'admin_session_hash' => null,
            'admin_session_expires_at' => null,
            'admin_session_by' => null,
        ]);
    }

    private static function expiryOf(string $hash): string
    {
        return Value::string(
            DB::table('kiosk_codes')->where('code_hash', $hash)->orderByDesc('id')->value('expires_at')
        );
    }

    /** Grouped for readability, e.g. K7F2-9QMX. */
    private static function generateCode(int $length): string
    {
        $max = strlen(self::CODE_ALPHABET) - 1;
        $out = '';

        for ($i = 0; $i < $length; $i++) {
            $out .= self::CODE_ALPHABET[random_int(0, $max)];
        }

        return substr($out, 0, 4).'-'.substr($out, 4);
    }

    private static function generateDigits(int $length): string
    {
        $out = '';

        for ($i = 0; $i < $length; $i++) {
            $out .= (string) random_int(0, 9);
        }

        return $out;
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
