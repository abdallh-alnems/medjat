<?php

declare(strict_types=1);

namespace App\Modules\Attendance\Domain;

use App\Support\Value;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;

/**
 * The rotating branch code: a short-lived nonce shown on a screen at the branch,
 * spendable once per employee.
 *
 * It exists because a printed code is a photograph away from being usable from
 * the car park. Rotating it means a forwarded screenshot is stale by the time it
 * arrives, and recording each use means the same live code cannot be shared
 * between two people.
 */
final class BranchQrChallenge
{
    /** How long a minted code stays valid. */
    public const TTL_SECONDS = 90;

    /** How often the display asks for a new one — shorter, so the windows overlap. */
    public const ROTATE_SECONDS = 30;

    /** MySQL's duplicate-key error. */
    private const DUPLICATE_ENTRY = 1062;

    /**
     * Spends a code for this employee.
     *
     * @return array{ok: bool, reason: string, message: string}
     */
    public static function consume(
        string $nonce,
        int $tenantId,
        int $branchId,
        int $employeeId,
        string $purpose = 'check_in',
    ): array {
        if ($nonce === '' || ! in_array($purpose, ['check_in', 'check_out'], true)) {
            return self::expired();
        }

        // Scoped to the branch as well as the company: a live code from branch A
        // must not open branch B, or a company with two sites effectively has
        // one code.
        $challengeId = DB::table('branch_qr_challenges')
            ->where('nonce', $nonce)
            ->where('tenant_id', $tenantId)
            ->where('branch_id', $branchId)
            ->where('expires_at', '>', DB::raw('NOW()'))
            ->value('id');

        if ($challengeId === null) {
            return self::expired();
        }

        try {
            DB::table('branch_qr_uses')->insert([
                'challenge_id' => $challengeId,
                'employee_id' => $employeeId,
                'purpose' => $purpose,
            ]);
        } catch (QueryException $e) {
            // A duplicate means this employee already spent this code. Anything
            // else — a foreign key failure, a dead connection — is a real fault
            // and must not be reported to the employee as a replay.
            if (self::isDuplicate($e)) {
                return [
                    'ok' => false,
                    'reason' => 'qr_replayed',
                    'message' => 'تم استخدام هذا الرمز بالفعل',
                ];
            }

            throw $e;
        }

        return ['ok' => true, 'reason' => '', 'message' => ''];
    }

    /**
     * @return array{ok: false, reason: string, message: string}
     */
    private static function expired(): array
    {
        return [
            'ok' => false,
            'reason' => 'qr_expired',
            'message' => 'انتهت صلاحية الرمز، امسح الرمز المعروض حالياً',
        ];
    }

    private static function isDuplicate(QueryException $e): bool
    {
        return Value::int($e->errorInfo[1] ?? null) === self::DUPLICATE_ENTRY;
    }

    /**
     * Mints the next code for a branch display.
     *
     * The window is longer than the rotation interval on purpose: they overlap,
     * so a code cannot expire between being rendered and being scanned.
     *
     * Expiry is computed by MySQL rather than PHP — PHP runs UTC here while
     * MySQL runs the server's zone, so a PHP-built timestamp lands hours in the
     * past and every code is born expired. face_challenges paid for that
     * mistake first.
     *
     * @return array{nonce: string, expires_in: int, rotate_in: int}
     */
    public static function issue(int $tenantId, int $branchId, ?int $issuedBy = null): array
    {
        $nonce = bin2hex(random_bytes(32));

        DB::insert(
            'INSERT INTO branch_qr_challenges (tenant_id, branch_id, nonce, expires_at, issued_by)
             VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND), ?)',
            [$tenantId, $branchId, $nonce, self::TTL_SECONDS, $issuedBy]
        );

        return [
            'nonce' => $nonce,
            'expires_in' => self::TTL_SECONDS,
            'rotate_in' => self::ROTATE_SECONDS,
        ];
    }

    /**
     * Removes challenges that stopped being valid a day ago.
     *
     * About volume, not secrecy — a row holds a random string and a timestamp.
     * But a branch display asks for a code every thirty seconds all day: one
     * screen writes roughly 2,900 rows a day, ten screens close to a million a
     * year, plus a use row per punch. The day of slack means a punch disputed
     * this morning can still be traced to the code that produced it.
     *
     * branch_qr_uses follows its parent by ON DELETE CASCADE, so deleting the
     * challenge is the whole job.
     */
    public static function purgeExpired(): int
    {
        return DB::table('branch_qr_challenges')
            ->whereRaw('expires_at < DATE_SUB(NOW(), INTERVAL 1 DAY)')
            ->delete();
    }
}
