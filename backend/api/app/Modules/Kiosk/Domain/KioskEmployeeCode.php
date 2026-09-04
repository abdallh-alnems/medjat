<?php

declare(strict_types=1);

namespace App\Modules\Kiosk\Domain;

use App\Exceptions\ApiFailure;
use Illuminate\Support\Facades\DB;

/**
 * The per-employee fallback code typed at a kiosk.
 *
 * Why this does not use a password hash, unlike every other secret here: the
 * browser PIN works with one because the employee has already identified
 * themselves by phone number, so it is a one-to-one check. A kiosk has no such
 * handle — the employee types a code and nothing else, and the code alone has
 * to resolve which person this is. Bcrypt cannot be looked up: finding the
 * owner would mean verifying against every employee at the branch, roughly
 * 100 ms each, so a 200-person branch would take twenty seconds per attempt.
 * That is not a tuning problem, it is the wrong primitive.
 *
 * So the code is looked up by a peppered SHA-256, with two compensating
 * decisions. Six digits, unique within the branch: six rather than four because
 * the hash is searchable, unique because a duplicate would make the code
 * ambiguous — the exact failure the whole feature exists to avoid. And a
 * server-side pepper held in configuration and never in the database, so a dump
 * of the employees table alone cannot be brute-forced back to codes.
 *
 * The real defence is not the hash. It is that this path is rate limited per
 * station, flagged to the security log when abused, revocable per employee, and
 * never a substitute for face identification.
 */
final class KioskEmployeeCode
{
    private const LENGTH = 6;

    /** Attempts to find an unused code before giving up. */
    private const MAX_GENERATION_TRIES = 40;

    /**
     * Falls back to the application secret, so a missing dedicated key degrades
     * to "still peppered" rather than to plaintext.
     */
    private static function pepper(): string
    {
        $pepper = config('kiosk.code_pepper');

        if (is_string($pepper) && $pepper !== '') {
            return $pepper;
        }

        $fallback = config('app.key');

        return is_string($fallback) && $fallback !== '' ? $fallback : 'permedjat-kiosk-fallback-pepper';
    }

    public static function hash(string $code): string
    {
        return hash_hmac('sha256', trim($code), self::pepper());
    }

    /**
     * Issues a fresh code, unique within the employee's branch.
     *
     * Returns the plaintext once. A reset invalidates the previous code the
     * moment this row is written — there is no grace period, because the reason
     * to reset is usually that the old one was shared.
     */
    public static function issueFor(int $employeeId, int $tenantId, int $branchId): string
    {
        for ($attempt = 0; $attempt < self::MAX_GENERATION_TRIES; $attempt++) {
            $code = self::randomDigits(self::LENGTH);
            $hash = self::hash($code);

            $clash = DB::table('employees')
                ->where('tenant_id', $tenantId)->where('branch_id', $branchId)
                ->where('kiosk_pin_hash', $hash)->where('id', '!=', $employeeId)
                ->exists();

            if ($clash) {
                continue;
            }

            DB::table('employees')->where('id', $employeeId)->where('tenant_id', $tenantId)->update([
                'kiosk_pin_hash' => $hash,
                'kiosk_pin_set_at' => DB::raw('NOW()'),
            ]);

            return $code;
        }

        // A branch would need a meaningful fraction of a million codes in use to
        // get here. Failing loudly beats handing out a duplicate.
        throw new ApiFailure(__('messages.kiosk_code_allocation_failed'), 500, 'kiosk_code_exhausted');
    }

    /**
     * Resolves a typed code to an employee at this branch.
     *
     * Scoped to the branch so the same six digits can belong to different people
     * at different sites, and so a code learned at one branch is useless at
     * another.
     *
     * @return array<string, mixed>|null
     */
    public static function resolve(string $code, int $tenantId, int $branchId): ?array
    {
        $code = trim($code);

        if (preg_match('/^\d{'.self::LENGTH.'}$/', $code) !== 1) {
            return null;
        }

        $row = DB::table('employees')
            ->where('tenant_id', $tenantId)->where('branch_id', $branchId)
            ->where('kiosk_pin_hash', self::hash($code))
            ->where('status', '!=', 'terminated')
            ->first(['id', 'name', 'branch_id', 'status', 'face_photo_url']);

        if ($row === null) {
            return null;
        }

        /** @var array<string, mixed> $columns */
        $columns = (array) $row;

        return $columns;
    }

    public static function clearFor(int $employeeId, int $tenantId): void
    {
        DB::table('employees')->where('id', $employeeId)->where('tenant_id', $tenantId)->update([
            'kiosk_pin_hash' => null,
            'kiosk_pin_set_at' => null,
        ]);
    }

    private static function randomDigits(int $length): string
    {
        $out = '';

        for ($i = 0; $i < $length; $i++) {
            $out .= (string) random_int(0, 9);
        }

        return $out;
    }
}
