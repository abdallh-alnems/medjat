<?php

declare(strict_types=1);

namespace App\Domain\Attendance;

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
}
