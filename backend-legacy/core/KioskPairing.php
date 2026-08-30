<?php


/**
 * Issues and redeems the two short-lived secrets a kiosk lives by.
 *
 *   pair   — turns an unconfigured tablet into a station bound to one branch.
 *   access — opens the administration area of a tablet already in service:
 *            enrollment, settings, and release of kiosk mode.
 *
 * Both are single-use, short-lived, and stored **hashed**. The hashing is the
 * one place this differs from `employee_activation_codes`, which keeps its code
 * in plaintext: an access code enrols faces and unlocks the tablet, so a
 * database read must not hand anybody a working key.
 *
 * Every expiry here is computed **in SQL**. PHP runs UTC on this server while
 * MySQL runs the tenant zone; a PHP-computed `expires_at` is born hours wrong,
 * which the face-challenge table already learned the hard way.
 */
final class KioskPairing {
    /** Long enough to walk to the tablet and type it; short enough to be useless if overheard. */
    public const PAIR_TTL_SECONDS = 900;   // 15 minutes

    /** Shorter: a supervisor reads it off a phone and types it immediately. */
    public const ACCESS_TTL_SECONDS = 300; // 5 minutes

    /** Ten minutes of enrolling, refreshed by activity — see open_admin.php. */
    public const ADMIN_SESSION_TTL_SECONDS = 600;

    /**
     * Human-typed on a tablet, so the alphabet excludes the characters people
     * confuse: 0/O, 1/I/L. Grouped for readability, e.g. K7F2-9QMX.
     */
    private const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

    public static function hash(string $plain): string {
        return hash('sha256', strtoupper(trim($plain)));
    }

    /**
     * Issues a pairing code for a branch.
     *
     * @return array{code: string, expires_at: string}
     */
    public static function issuePairCode(int $tenantId, int $branchId, int $createdBy): array {
        $code = self::generateCode(8, true);

        Database::execute(
            "INSERT INTO kiosk_codes
                (tenant_id, branch_id, station_id, purpose, code_hash, expires_at, created_by)
             VALUES (?, ?, NULL, 'pair', ?, DATE_ADD(NOW(), INTERVAL ? SECOND), ?)",
            [$tenantId, $branchId, self::hash($code), self::PAIR_TTL_SECONDS, $createdBy]
        );

        return ['code' => $code, 'expires_at' => self::expiryOf(self::hash($code))];
    }

    /**
     * Issues an access code for a station already in service.
     *
     * Digits only: this one is typed far more often than a pairing code, often
     * by someone holding a phone in the other hand.
     *
     * @return array{code: string, expires_at: string}
     */
    public static function issueAccessCode(int $tenantId, int $branchId, int $stationId, int $createdBy): array {
        $code = self::generateDigits(6);

        Database::execute(
            "INSERT INTO kiosk_codes
                (tenant_id, branch_id, station_id, purpose, code_hash, expires_at, created_by)
             VALUES (?, ?, ?, 'access', ?, DATE_ADD(NOW(), INTERVAL ? SECOND), ?)",
            [$tenantId, $branchId, $stationId, self::hash($code), self::ACCESS_TTL_SECONDS, $createdBy]
        );

        return ['code' => $code, 'expires_at' => self::expiryOf(self::hash($code))];
    }

    /**
     * Consumes a code, atomically.
     *
     * The lookup, the expiry check, and the `used_at` write are one guarded
     * UPDATE rather than a SELECT followed by an UPDATE. Two tablets racing the
     * same code is not hypothetical — a supervisor pairing several devices will
     * type the same code twice by accident — and a read-then-write would let
     * both through.
     *
     * Zero affected rows means unknown, expired, or already consumed. The caller
     * must not distinguish those three in its response: an endpoint that says
     * "expired" rather than "unknown" is an oracle for guessing codes.
     *
     * @return array|null The consumed row, or null if it was not consumable.
     */
    public static function consume(string $plainCode, string $purpose, ?int $stationId = null): ?array {
        $hash = self::hash($plainCode);

        $affected = Database::execute(
            "UPDATE kiosk_codes
                SET used_at = NOW(), used_by_station = ?
              WHERE code_hash = ?
                AND purpose = ?
                AND used_at IS NULL
                AND expires_at > NOW()",
            [$stationId, $hash, $purpose]
        );

        if ($affected === 0) {
            return null;
        }

        return Database::fetchOne(
            "SELECT * FROM kiosk_codes WHERE code_hash = ? AND purpose = ? ORDER BY id DESC LIMIT 1",
            [$hash, $purpose]
        );
    }

    /**
     * Pairs a tablet: creates the station and issues its credential.
     *
     * @return array{station_id: int, token: string}
     */
    public static function pairDevice(
        array $code,
        string $deviceId,
        ?string $deviceModel,
        string $platform,
        ?string $appVersion,
        ?string $name
    ): array {
        $stationId = KioskStationModel::create(
            (int) $code['tenant_id'],
            (int) $code['branch_id'],
            $name,
            $deviceModel,
            $platform,
            $appVersion,
            (int) $code['created_by']
        );

        // Record which station consumed the code, now that one exists. The
        // guarded UPDATE above could not do this: the station is created here.
        Database::execute(
            "UPDATE kiosk_codes SET used_by_station = ? WHERE id = ?",
            [$stationId, (int) $code['id']]
        );

        $token = KioskTokenModel::issueFor((int) $code['tenant_id'], $stationId, $deviceId);

        return ['station_id' => $stationId, 'token' => $token];
    }

    /**
     * Opens the administration area on a station.
     *
     * Stored hashed on the station row: exactly one session per tablet, because
     * a tablet has exactly one administration area. Returns the plaintext once.
     */
    public static function openAdminSession(int $stationId, int $authorisedBy): string {
        $plain = bin2hex(random_bytes(32));

        Database::execute(
            "UPDATE attendance_stations
                SET admin_session_hash = ?,
                    admin_session_expires_at = DATE_ADD(NOW(), INTERVAL ? SECOND),
                    admin_session_by = ?
              WHERE id = ?",
            [hash('sha256', $plain), self::ADMIN_SESSION_TTL_SECONDS, $authorisedBy, $stationId]
        );

        return $plain;
    }

    /**
     * Validates an admin session and extends it.
     *
     * Refreshing on every call is what lets a supervisor work through a queue
     * of thirty people without being thrown out mid-enrollment, while an
     * abandoned screen still closes itself within the TTL.
     *
     * @return array|null The station row, or null if the session is closed or expired.
     */
    public static function touchAdminSession(int $stationId, string $plain): ?array {
        $station = Database::fetchOne(
            "SELECT * FROM attendance_stations
              WHERE id = ?
                AND admin_session_hash = ?
                AND admin_session_expires_at > NOW()
              LIMIT 1",
            [$stationId, hash('sha256', $plain)]
        );

        if (!$station) {
            return null;
        }

        Database::execute(
            "UPDATE attendance_stations
                SET admin_session_expires_at = DATE_ADD(NOW(), INTERVAL ? SECOND)
              WHERE id = ?",
            [self::ADMIN_SESSION_TTL_SECONDS, $stationId]
        );

        return $station;
    }

    public static function closeAdminSession(int $stationId): void {
        Database::execute(
            "UPDATE attendance_stations
                SET admin_session_hash = NULL,
                    admin_session_expires_at = NULL,
                    admin_session_by = NULL
              WHERE id = ?",
            [$stationId]
        );
    }

    private static function expiryOf(string $hash): string {
        $row = Database::fetchOne(
            "SELECT expires_at FROM kiosk_codes WHERE code_hash = ? ORDER BY id DESC LIMIT 1",
            [$hash]
        );
        return $row['expires_at'] ?? '';
    }

    private static function generateCode(int $length, bool $grouped = false): string {
        $alphabet = self::CODE_ALPHABET;
        $max = strlen($alphabet) - 1;

        $out = '';
        for ($i = 0; $i < $length; $i++) {
            $out .= $alphabet[random_int(0, $max)];
        }

        return $grouped ? substr($out, 0, 4) . '-' . substr($out, 4) : $out;
    }

    private static function generateDigits(int $length): string {
        $out = '';
        for ($i = 0; $i < $length; $i++) {
            $out .= (string) random_int(0, 9);
        }
        return $out;
    }
}
