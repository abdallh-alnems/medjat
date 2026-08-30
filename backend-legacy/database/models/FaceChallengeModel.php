<?php

/**
 * Single-use liveness challenges for face check-in.
 *
 * The device asks for a challenge, performs it (blink / turn / smile), and
 * returns the nonce with the embedding. Without this the client could replay
 * one captured embedding forever, since an embedding is just a list of floats.
 */
final class FaceChallengeModel {
    /** Long enough for a slow capture on a weak phone, short enough to be useless later. */
    private const TTL_SECONDS = 120;

    /**
     * Issues a fresh challenge, replacing any outstanding one for this
     * employee + purpose so only the newest attempt can ever be completed.
     *
     * @return array{nonce: string, challenge: string, expires_in: int}
     */
    public static function issue(int $tenantId, int $employeeId, string $purpose): array {
        Database::execute(
            "DELETE FROM face_challenges
             WHERE tenant_id = ? AND employee_id = ? AND purpose = ?",
            [$tenantId, $employeeId, $purpose]
        );

        $nonce = bin2hex(random_bytes(32));
        $challenge = FaceMatchService::CHALLENGES[random_int(0, count(FaceMatchService::CHALLENGES) - 1)];

        // The expiry is computed by MySQL, not PHP. PHP runs in UTC here while
        // MySQL uses system time (Africa/Cairo), so a PHP-built timestamp lands
        // hours in the past and every challenge is born expired. Comparing
        // NOW() against a NOW()-derived value keeps both sides on one clock.
        Database::execute(
            "INSERT INTO face_challenges (tenant_id, employee_id, nonce, challenge, purpose, expires_at)
             VALUES (?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND))",
            [$tenantId, $employeeId, $nonce, $challenge, $purpose, self::TTL_SECONDS]
        );

        return [
            'nonce' => $nonce,
            'challenge' => $challenge,
            'expires_in' => self::TTL_SECONDS,
        ];
    }

    /**
     * Validates and burns a challenge. Returns null when the nonce is unknown,
     * expired, already used, or belongs to someone else.
     *
     * The UPDATE doubles as the atomic claim: `consumed_at IS NULL` in the
     * WHERE means two concurrent requests can never both win.
     */
    public static function consume(string $nonce, int $tenantId, int $employeeId, string $purpose): ?array {
        if ($nonce === '') {
            return null;
        }

        $affected = Database::execute(
            "UPDATE face_challenges
             SET consumed_at = NOW()
             WHERE nonce = ? AND tenant_id = ? AND employee_id = ? AND purpose = ?
               AND consumed_at IS NULL AND expires_at > NOW()",
            [$nonce, $tenantId, $employeeId, $purpose]
        );

        if ($affected < 1) {
            return null;
        }

        return Database::fetchOne(
            "SELECT id, challenge, purpose FROM face_challenges WHERE nonce = ? LIMIT 1",
            [$nonce]
        );
    }

    /** Housekeeping for the attendance cron: drop spent/expired rows. */
    public static function purgeExpired(): int {
        return Database::execute(
            "DELETE FROM face_challenges
             WHERE expires_at < DATE_SUB(NOW(), INTERVAL 1 DAY)"
        );
    }
}
