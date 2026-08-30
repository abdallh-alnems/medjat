<?php

/**
 * Time-limited QR codes shown on a screen at a branch door.
 *
 * A printed branch code never changes, so holding it says nothing about being
 * at the branch — a photograph of the sheet is as good as standing at the door,
 * forever. The geofence stops that turning into check-in-from-home, but it
 * cannot separate "at the door" from "in the café next door": the default radius
 * is 100 metres. A rotating code puts the second factor back, because the only
 * way to hold a current one is to be looking at the screen.
 *
 * Shaped differently from FaceChallengeModel on purpose. A face challenge is
 * minted for one employee and is single-use, so it carries `consumed_at`. A
 * branch code is scanned by everyone arriving in the same window; burning it on
 * first use would refuse everybody after the first person through the door. So
 * the code is valid for a window for all comers, and a separate row records that
 * a particular employee has spent it.
 */
final class BranchQrChallengeModel {
    /**
     * How long a displayed code stays valid.
     *
     * Longer than ROTATE_SECONDS on purpose, so validity windows overlap. With
     * TTL == rotation there is a guaranteed race: the code on screen at 29.9s
     * expires while the camera is still focusing and the employee gets a failure
     * they can do nothing about. A few concurrently valid codes is a rounding
     * error next to a code that is valid forever.
     */
    public const TTL_SECONDS = 90;

    /** How often the display should ask for a new code. */
    public const ROTATE_SECONDS = 30;

    /**
     * Mints a code for a branch display.
     *
     * Unlike the face flow this does NOT delete the branch's previous codes:
     * the ones still inside their TTL are being scanned right now by people
     * standing at the door.
     *
     * @return array{nonce: string, expires_in: int, rotate_in: int}
     */
    public static function issue(int $tenantId, int $branchId, ?int $issuedBy = null): array {
        $nonce = bin2hex(random_bytes(32));

        // Expiry is computed by MySQL, not PHP. PHP runs UTC here while MySQL
        // runs the server zone, so a PHP-built timestamp lands hours in the past
        // and every code is born expired — the mistake face_challenges paid for.
        Database::execute(
            "INSERT INTO branch_qr_challenges (tenant_id, branch_id, nonce, expires_at, issued_by)
             VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND), ?)",
            [$tenantId, $branchId, $nonce, self::TTL_SECONDS, $issuedBy]
        );

        return [
            'nonce' => $nonce,
            'expires_in' => self::TTL_SECONDS,
            'rotate_in' => self::ROTATE_SECONDS,
        ];
    }

    /**
     * Validates a scanned code and records that this employee has spent it.
     *
     * The INSERT is the claim, not a preceding SELECT: the unique key on
     * (challenge_id, employee_id, purpose) means two concurrent requests cannot
     * both succeed, and there is no window between checking and claiming.
     *
     * Distinguishes the two failures because they mean different things to the
     * person holding the phone, and to whoever reads the security log:
     *   qr_expired  — the code is unknown, lapsed, or belongs to another branch.
     *                 Usually innocent: a slow scan, or a stale screen.
     *   qr_replayed — the code is live but this employee already used it for
     *                 this purpose. That is a forwarded screenshot, not a
     *                 mistake.
     *
     * @param string $purpose check_in|check_out — an employee may legitimately
     *                        arrive and leave inside one window, so the purpose
     *                        is part of the claim.
     * @return array{ok: bool, reason: ?string}
     */
    public static function consume(
        string $nonce,
        int $tenantId,
        int $branchId,
        int $employeeId,
        string $purpose = 'check_in'
    ): array {
        if ($nonce === '' || !in_array($purpose, ['check_in', 'check_out'], true)) {
            return ['ok' => false, 'reason' => 'qr_expired'];
        }

        // Scoped to the branch as well as the tenant: a live code from branch A
        // must not open branch B, or a company with two sites has one code.
        $challenge = Database::fetchOne(
            "SELECT id FROM branch_qr_challenges
             WHERE nonce = ? AND tenant_id = ? AND branch_id = ? AND expires_at > NOW()
             LIMIT 1",
            [$nonce, $tenantId, $branchId]
        );

        if (!$challenge) {
            return ['ok' => false, 'reason' => 'qr_expired'];
        }

        try {
            Database::execute(
                "INSERT INTO branch_qr_uses (challenge_id, employee_id, purpose) VALUES (?, ?, ?)",
                [(int) $challenge['id'], $employeeId, $purpose]
            );
        } catch (PDOException $e) {
            // 1062 = duplicate entry, i.e. this employee already spent this code.
            // Anything else (a foreign key failure, a dead connection) is a real
            // fault and must not be reported to the employee as a replay.
            if (($e->errorInfo[1] ?? null) === 1062) {
                return ['ok' => false, 'reason' => 'qr_replayed'];
            }
            throw $e;
        }

        return ['ok' => true, 'reason' => null];
    }

    /** True when this branch requires a rotating code rather than the printed one. */
    public static function isEnabledForBranch(array $branch): bool {
        return (int) ($branch['rotating_qr_enabled'] ?? 0) === 1;
    }

    /**
     * Housekeeping for the attendance cron.
     *
     * Spent-use rows go with their challenge via ON DELETE CASCADE, so this is
     * the only purge either table needs. The day of slack keeps recent history
     * available for anyone investigating a disputed punch.
     */
    public static function purgeExpired(): int {
        return Database::execute(
            "DELETE FROM branch_qr_challenges
             WHERE expires_at < DATE_SUB(NOW(), INTERVAL 1 DAY)"
        );
    }
}
