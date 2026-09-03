<?php

/**
 * The per-employee fallback code typed at a kiosk.
 *
 * ---- Why this does not use password_hash(), unlike every other secret here ---
 *
 * `EmployeeWebCredentialModel` hashes the browser PIN with `password_hash()` and
 * checks it with `password_verify()`. That works there because the employee has
 * already identified themselves by phone number: it is a **one-to-one** check.
 *
 * A kiosk has no such handle. The employee types a code and nothing else — the
 * code alone has to resolve *which* person this is. Bcrypt cannot be looked up:
 * finding the owner would mean `password_verify()` against every employee at the
 * branch, roughly 100 ms each, so a 200-person branch would take twenty seconds
 * per attempt. That is not a tuning problem, it is the wrong primitive.
 *
 * So the code is looked up by a **peppered SHA-256**, with two compensating
 * decisions:
 *
 *   1. **Six digits, unique within the branch.** Six rather than four because
 *      the hash is searchable and the space should not be 10,000. Unique because
 *      a duplicate would make the code ambiguous, which is the exact failure the
 *      whole feature is built to avoid.
 *   2. **A server-side pepper**, held in config and never in the database. A
 *      dump of `employees` alone cannot be brute-forced back to codes; an
 *      attacker needs the application secret too. Per-row salting is impossible
 *      here for the same reason bcrypt is — it would break the lookup.
 *
 * The real defence is not the hash. It is that this path is rate limited per
 * station, flagged to the security log when it is abused, per-employee
 * revocable, and — by FR-042 — never a substitute for face identification.
 */
final class KioskEmployeeCode {
    private const LENGTH = 6;

    /** Attempts to find an unused code before giving up. */
    private const MAX_GENERATION_TRIES = 40;

    /**
     * Server-side pepper. Falls back to the app's shared secret so a missing
     * dedicated key degrades to "still peppered" rather than to plaintext.
     */
    private static function pepper(): string {
        $pepper = getenv('KIOSK_CODE_PEPPER');
        if (is_string($pepper) && $pepper !== '') {
            return $pepper;
        }
        return (string) (getenv('SECURITY_KEY') ?: 'permedjat-kiosk-fallback-pepper');
    }

    public static function hash(string $code): string {
        return hash_hmac('sha256', trim($code), self::pepper());
    }

    /**
     * Issues a fresh code for an employee, unique within their branch.
     *
     * Returns the plaintext once. A reset invalidates the previous code the
     * moment this row is written — there is no grace period, because the reason
     * to reset is usually that the old one was shared.
     */
    public static function issueFor(int $employeeId, int $tenantId, int $branchId): string {
        for ($i = 0; $i < self::MAX_GENERATION_TRIES; $i++) {
            $code = self::randomDigits(self::LENGTH);
            $hash = self::hash($code);

            $clash = Database::fetchOne(
                "SELECT id FROM employees
                  WHERE tenant_id = ? AND branch_id = ? AND kiosk_pin_hash = ? AND id <> ?
                  LIMIT 1",
                [$tenantId, $branchId, $hash, $employeeId]
            );

            if ($clash) {
                continue;
            }

            Database::execute(
                "UPDATE employees SET kiosk_pin_hash = ?, kiosk_pin_set_at = NOW()
                  WHERE id = ? AND tenant_id = ?",
                [$hash, $employeeId, $tenantId]
            );

            return $code;
        }

        // A branch would need a meaningful fraction of a million codes in use to
        // get here. Failing loudly beats handing out a duplicate.
        Response::fail('Could not allocate a unique kiosk code', 500, 'kiosk_code_exhausted');
    }

    /**
     * Resolves a typed code to an employee at this branch.
     *
     * Scoped to the branch so the same six digits can belong to different people
     * at different sites, and so a code learned at one branch is useless at
     * another.
     */
    public static function resolve(string $code, int $tenantId, int $branchId): ?array {
        if (!preg_match('/^\d{' . self::LENGTH . '}$/', trim($code))) {
            return null;
        }

        return Database::fetchOne(
            "SELECT id, name, branch_id, status, face_photo_url
               FROM employees
              WHERE tenant_id = ? AND branch_id = ? AND kiosk_pin_hash = ?
                AND status <> 'terminated'
              LIMIT 1",
            [$tenantId, $branchId, self::hash($code)]
        );
    }

    public static function clearFor(int $employeeId, int $tenantId): void {
        Database::execute(
            "UPDATE employees SET kiosk_pin_hash = NULL, kiosk_pin_set_at = NULL
              WHERE id = ? AND tenant_id = ?",
            [$employeeId, $tenantId]
        );
    }

    private static function randomDigits(int $length): string {
        $out = '';
        for ($i = 0; $i < $length; $i++) {
            $out .= (string) random_int(0, 9);
        }
        return $out;
    }
}
