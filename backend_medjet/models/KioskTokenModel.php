<?php

/**
 * The credential a kiosk tablet presents on every request.
 *
 * Mirrors EmployeeAuthTokenModel, with one difference that matters more than it
 * looks: this token resolves to a **branch**, never to a person. An employee
 * token can only record attendance for its owner; a kiosk token can record
 * attendance for anyone enrolled at its branch. That is why it is revocable
 * from the management app, why only the hash is stored, and why every lookup
 * here re-checks that the station itself is still active.
 */
final class KioskTokenModel {
    /**
     * Resolves a presented token to its station.
     *
     * Joins the station rather than trusting the token row alone: revoking a
     * station and revoking its token are two writes, and a partially applied
     * revocation must fail closed.
     */
    public static function findActiveByPlain(string $plain): ?array {
        $hash = hash('sha256', $plain);

        return Database::fetchOne(
            "SELECT t.id, t.tenant_id, t.station_id, t.device_id,
                    s.branch_id, s.name AS station_name, s.status AS station_status,
                    s.app_version
               FROM kiosk_auth_tokens t
               JOIN attendance_stations s ON s.id = t.station_id
              WHERE t.token_hash = ?
                AND t.revoked_at IS NULL
                AND s.status = 'active'
              LIMIT 1",
            [$hash]
        );
    }

    /**
     * Issues the station's token and returns the plaintext.
     *
     * The plaintext exists only in this return value and in the pairing
     * response. It is never stored, never logged, and cannot be recovered — a
     * database read must not hand anybody a working branch-wide credential.
     */
    public static function issueFor(int $tenantId, int $stationId, string $deviceId): string {
        // One live token per station. Re-pairing the same tablet replaces the
        // old credential rather than leaving two valid ones behind.
        self::revokeForStation($stationId, 'replaced');

        $plain = bin2hex(random_bytes(32));

        Database::execute(
            "INSERT INTO kiosk_auth_tokens (tenant_id, station_id, token_hash, device_id)
             VALUES (?, ?, ?, ?)",
            [$tenantId, $stationId, hash('sha256', $plain), $deviceId]
        );

        return $plain;
    }

    /**
     * Revokes whatever live token the station holds.
     *
     * Sets `revoked_at` rather than deleting: the unique key on
     * (station_id, revoked_at) relies on MySQL treating NULLs as distinct, so
     * revoked rows accumulate harmlessly and the device history survives.
     */
    public static function revokeForStation(int $stationId, string $reason): void {
        Database::execute(
            "UPDATE kiosk_auth_tokens
                SET revoked_at = NOW(), revoke_reason = ?
              WHERE station_id = ? AND revoked_at IS NULL",
            [$reason, $stationId]
        );
    }

    public static function touchUsed(int $tokenId): void {
        Database::execute(
            "UPDATE kiosk_auth_tokens SET last_used_at = NOW() WHERE id = ?",
            [$tokenId]
        );
    }
}
