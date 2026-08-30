<?php

declare(strict_types=1);

namespace App\Domain\Face;

use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * The single-use liveness challenge.
 *
 * The app asks for one immediately before opening the camera, performs the
 * action it names, and sends the nonce back with the embedding. Without it a
 * captured embedding could be submitted whenever its holder liked — the nonce is
 * what makes an attempt belong to a moment.
 */
final class FaceChallenge
{
    /** Long enough to blink and frame a face, short enough to be worthless later. */
    private const TTL_SECONDS = 120;

    /**
     * @return array{nonce: string, challenge: string, expires_in: int}
     */
    public static function issue(int $tenantId, int $employeeId, string $purpose): array
    {
        // One live challenge per employee per purpose: holding several would let
        // somebody bank them.
        DB::table('face_challenges')
            ->where('tenant_id', $tenantId)
            ->where('employee_id', $employeeId)
            ->where('purpose', $purpose)
            ->delete();

        $nonce = bin2hex(random_bytes(32));
        $challenge = FaceMatcher::CHALLENGES[random_int(0, count(FaceMatcher::CHALLENGES) - 1)];

        // The expiry is computed by MySQL, not PHP. PHP runs UTC here while
        // MySQL uses the server's zone, so a PHP-built timestamp lands hours in
        // the past and every challenge is born expired. Comparing NOW() against
        // a NOW()-derived value keeps both sides on one clock.
        DB::insert(
            'INSERT INTO face_challenges (tenant_id, employee_id, nonce, challenge, purpose, expires_at)
             VALUES (?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND))',
            [$tenantId, $employeeId, $nonce, $challenge, $purpose, self::TTL_SECONDS]
        );

        return ['nonce' => $nonce, 'challenge' => $challenge, 'expires_in' => self::TTL_SECONDS];
    }

    /**
     * Spends a nonce, returning the challenge word it named — or null when it
     * is spent, expired or unknown.
     *
     * Enrollment and check-in both come through here, so a nonce cannot be
     * issued for one and redeemed against the other, and neither can be
     * loosened without the other noticing.
     */
    public static function consume(string $nonce, int $tenantId, int $employeeId, string $purpose): ?string
    {
        if ($nonce === '') {
            return null;
        }

        // Claimed with the guard inside the UPDATE so two racing requests cannot
        // both spend it, and expiry compared by the database's own clock.
        $claimed = DB::update(
            'UPDATE face_challenges
                SET consumed_at = NOW()
              WHERE nonce = ? AND tenant_id = ? AND employee_id = ? AND purpose = ?
                AND consumed_at IS NULL AND expires_at > NOW()',
            [$nonce, $tenantId, $employeeId, $purpose]
        );

        if ($claimed < 1) {
            return null;
        }

        return Value::nullableString(DB::table('face_challenges')->where('nonce', $nonce)->value('challenge'));
    }
}
