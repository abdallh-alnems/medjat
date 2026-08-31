<?php

/**
 * The employee's reusable secret for browser sign-in.
 *
 * The mobile app never needed one: it exchanges a single-use activation code for
 * a token that never expires, which is safe enough on a personal phone. A
 * browser is opened on office computers and borrowed handsets, so its session
 * has to end — and the moment it ends, the employee needs something to get back
 * in with. The activation code cannot serve: it is consumed on first use and
 * lapses after 24 hours.
 *
 * Six digits rather than four. The sign-in page is reachable by anyone with the
 * link, unlike the app's login, so the guessing surface is genuinely new. The
 * real bound is the lockout below — rate limiting only slows guessing down.
 */
final class EmployeeWebCredentialModel {
    /** Consecutive failures before the credential locks. Only an admin reset clears it. */
    public const MAX_FAILED_ATTEMPTS = 5;

    /** How long a lockout lasts. Long enough to be useless to a script, short enough to survive a typo streak. */
    private const LOCKOUT_SECONDS = 900; // 15 minutes

    private const PIN_LENGTH = 6;

    public static function findByEmployee(int $employeeId, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT id, tenant_id, employee_id, pin_hash, failed_attempts, locked_until,
                    pin_set_at, last_used_at
             FROM employee_web_credentials
             WHERE employee_id = ? AND tenant_id = ?
             LIMIT 1",
            [$employeeId, $tenantId]
        );
    }

    /**
     * The handful of 6-digit PINs that dominate every leaked dataset.
     *
     * Runs and repeated blocks are caught structurally below; these are the ones
     * that are neither — people reach for them because they are easy to type on
     * a keypad, not because they follow a rule.
     */
    private const BANNED_PINS = [
        '123456', '654321', '012345', '543210',
        '123123', '112233', '121212', '123321', '696969',
        '159753', '147258', '135790', '102030', '123654',
    ];

    /**
     * Rejects PINs that are trivially guessable.
     *
     * Six digits is a million combinations, but real people do not pick from a
     * million — a handful of shapes account for a large share of every leaked
     * PIN dataset, and an attacker tries those first. Screening them costs a few
     * rejected attempts at signup and removes the cheapest attack outright.
     *
     * What is deliberately NOT screened: anything requiring the employee to
     * remember a rule. This is entered on a phone keypad several times a week by
     * a workforce that is not uniformly literate in Latin script, so every extra
     * constraint has to earn its friction. Length is fixed at 6 for the same
     * reason.
     */
    public static function validatePinFormat(?string $pin): bool {
        return self::rejectReason($pin) === null;
    }

    /**
     * Why a PIN was rejected, or null when it is acceptable.
     *
     * Separated from the boolean so the interface can say what is wrong instead
     * of "invalid" — an employee told only that their choice failed will try
     * another guessable one.
     *
     * @return string|null One of: length, repeated, sequence, pattern, common, phone
     */
    public static function rejectReason(?string $pin, ?string $employeePhone = null): ?string {
        if (!is_string($pin) || !preg_match('/^\d{' . self::PIN_LENGTH . '}$/', $pin)) {
            return 'length';
        }

        // 000000, 111111 …
        if (preg_match('/^(\d)\1+$/', $pin)) {
            return 'repeated';
        }

        // Any run of consecutive digits in either direction — 123456, 234567,
        // 987654. Checked structurally rather than listed, because a list of
        // "the obvious ones" always misses the run that starts one digit over.
        $ascending = true;
        $descending = true;
        for ($i = 1; $i < self::PIN_LENGTH; $i++) {
            $step = (int) $pin[$i] - (int) $pin[$i - 1];
            if ($step !== 1) {
                $ascending = false;
            }
            if ($step !== -1) {
                $descending = false;
            }
        }
        if ($ascending || $descending) {
            return 'sequence';
        }

        // A short block repeated to fill the length: 121212 (2), 123123 (3),
        // 112233 is caught by the list. These read as random to the person
        // choosing them and are near the top of every cracking dictionary.
        foreach ([2, 3] as $blockLength) {
            $block = substr($pin, 0, $blockLength);
            if ($pin === str_repeat($block, (int) (self::PIN_LENGTH / $blockLength))) {
                return 'pattern';
            }
        }

        if (in_array($pin, self::BANNED_PINS, true)) {
            return 'common';
        }

        // The phone number is the *username* on this channel. A PIN taken from
        // it is guessable by anyone who already knows the one thing they must
        // know to attack the account at all, which makes it the single worst
        // choice available — and a common one.
        if (is_string($employeePhone) && $employeePhone !== '') {
            $digits = preg_replace('/\D/', '', $employeePhone);
            if ($digits !== '' && str_contains($digits, $pin)) {
                return 'phone';
            }
        }

        return null;
    }

    /** Creates or replaces the credential. Called only after a valid activation code is consumed. */
    public static function set(int $tenantId, int $employeeId, string $pin): void {
        $hash = password_hash($pin, PASSWORD_DEFAULT);

        Database::execute(
            "INSERT INTO employee_web_credentials
                (tenant_id, employee_id, pin_hash, failed_attempts, locked_until, pin_set_at)
             VALUES (?, ?, ?, 0, NULL, NOW())
             ON DUPLICATE KEY UPDATE
                pin_hash = VALUES(pin_hash),
                tenant_id = VALUES(tenant_id),
                failed_attempts = 0,
                locked_until = NULL,
                pin_set_at = NOW()",
            [$tenantId, $employeeId, $hash]
        );
    }

    /**
     * True when the credential is currently locked out.
     *
     * Evaluated **in SQL** against the database's own clock. PHP runs UTC on the
     * server and MySQL does not, so comparing here would unlock accounts hours
     * early — the same trap that produced born-expired face challenges.
     */
    public static function isLocked(int $employeeId): bool {
        $row = Database::fetchOne(
            "SELECT 1 AS locked
             FROM employee_web_credentials
             WHERE employee_id = ? AND locked_until IS NOT NULL AND locked_until > NOW()
             LIMIT 1",
            [$employeeId]
        );
        return $row !== null;
    }

    public static function verifyPin(array $credential, string $pin): bool {
        return password_verify($pin, (string) $credential['pin_hash']);
    }

    /** Clears the failure counter after a successful sign-in. */
    public static function recordSuccess(int $employeeId): void {
        Database::execute(
            "UPDATE employee_web_credentials
             SET failed_attempts = 0, locked_until = NULL, last_used_at = NOW()
             WHERE employee_id = ?",
            [$employeeId]
        );
    }

    /**
     * Counts a wrong PIN and locks the credential once the limit is reached.
     *
     * @return bool True if this failure caused a lockout.
     */
    public static function recordFailure(int $employeeId): bool {
        // Two statements on purpose. Doing the increment and the lock decision in
        // one UPDATE reads naturally but is wrong: MySQL evaluates SET
        // assignments left to right and later expressions see the *new* value of
        // columns already assigned, so a `CASE WHEN failed_attempts + 1 >= 5`
        // sitting after `failed_attempts = failed_attempts + 1` actually tests
        // the original + 2 — and the account locks an attempt early. That was
        // caught by counting the attempts in a test, not by reading the query.
        Database::execute(
            'UPDATE employee_web_credentials SET failed_attempts = failed_attempts + 1 WHERE employee_id = ?',
            [$employeeId]
        );

        // Lock time still comes from the database clock, never from PHP.
        Database::execute(
            "UPDATE employee_web_credentials
             SET locked_until = DATE_ADD(NOW(), INTERVAL ? SECOND)
             WHERE employee_id = ? AND failed_attempts >= ?",
            [self::LOCKOUT_SECONDS, $employeeId, self::MAX_FAILED_ATTEMPTS]
        );

        return self::isLocked($employeeId);
    }

    /** Removes the credential entirely — an administrator reset. */
    public static function clear(int $employeeId, int $tenantId): void {
        Database::execute(
            'DELETE FROM employee_web_credentials WHERE employee_id = ? AND tenant_id = ?',
            [$employeeId, $tenantId]
        );
    }
}
