<?php

final class ActivationCodeModel {
    private const CODE_LENGTH = 6;
    private const VALIDITY_HOURS = 24;

    /**
     * Create a fresh activation row holding both the hand-typed `code` and a
     * long opaque `token` (used by the join link / QR). Returns both plus the
     * expiry so callers can build the link and tell the admin when it lapses.
     *
     * @return array{code:string, token:string, expires_at:string}
     */
    public static function generate(int $tenantId, int $employeeId): array {
        self::invalidateExistingForEmployee($employeeId);

        $code = self::generateUniqueCode();
        $token = self::generateUniqueToken();
        $expiresAt = date('Y-m-d H:i:s', strtotime('+' . self::VALIDITY_HOURS . ' hours'));

        Database::execute(
            "INSERT INTO employee_activation_codes (tenant_id, employee_id, code, token, expires_at)
             VALUES (?, ?, ?, ?, ?)",
            [$tenantId, $employeeId, $code, $token, $expiresAt]
        );

        return ['code' => $code, 'token' => $token, 'expires_at' => $expiresAt];
    }

    public static function findActive(int $employeeId): ?array {
        return Database::fetchOne(
            "SELECT * FROM employee_activation_codes
             WHERE employee_id = ? AND used_at IS NULL AND expires_at > NOW()
             ORDER BY created_at DESC LIMIT 1",
            [$employeeId]
        );
    }

    public static function findByCode(string $code): ?array {
        return Database::fetchOne(
            "SELECT * FROM employee_activation_codes
             WHERE code = ? AND used_at IS NULL AND expires_at > NOW() LIMIT 1",
            [$code]
        );
    }

    /**
     * Build the deep link the employee opens to join. Android App Links / iOS
     * Universal Links require an https URL on a domain we control; the app
     * intercepts it, and a web landing page (join.php) is the fallback when the
     * app isn't installed. Base is configurable via APP_JOIN_BASE_URL.
     */
    public static function buildJoinLink(string $token): string {
        $base = rtrim(getenv('APP_JOIN_BASE_URL') ?: 'https://permedjat.com', '/');
        return $base . '/join?token=' . urlencode($token);
    }

    public static function findByToken(string $token): ?array {
        return Database::fetchOne(
            "SELECT * FROM employee_activation_codes
             WHERE token = ? AND used_at IS NULL AND expires_at > NOW() LIMIT 1",
            [$token]
        );
    }

    public static function markUsed(int $codeId, string $firebaseUid): void {
        Database::execute(
            "UPDATE employee_activation_codes
             SET used_at = NOW(), used_by_firebase_uid = ?
             WHERE id = ?",
            [$firebaseUid, $codeId]
        );
    }

    public static function markUsedByDevice(int $codeId, string $deviceId): void {
        Database::execute(
            "UPDATE employee_activation_codes
             SET used_at = NOW(), used_by_firebase_uid = ?
             WHERE id = ?",
            ['device:' . $deviceId, $codeId]
        );
    }

    private static function invalidateExistingForEmployee(int $employeeId): void {
        Database::execute(
            "UPDATE employee_activation_codes
             SET expires_at = NOW()
             WHERE employee_id = ? AND used_at IS NULL AND expires_at > NOW()",
            [$employeeId]
        );
    }

    private static function generateUniqueCode(): string {
        // PRD §3.6: 6 alphanumeric uppercase chars (digits + uppercase letters)
        // Excludes 0/O/I/1 to avoid visual confusion when read aloud.
        $alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
        $alphabetLen = strlen($alphabet);
        do {
            $code = '';
            for ($i = 0; $i < self::CODE_LENGTH; $i++) {
                $code .= $alphabet[random_int(0, $alphabetLen - 1)];
            }
            $exists = Database::fetchOne(
                "SELECT id FROM employee_activation_codes WHERE code = ? AND used_at IS NULL LIMIT 1",
                [$code]
            );
        } while ($exists);
        return $code;
    }

    private static function generateUniqueToken(): string {
        // 32 random bytes → 64 hex chars. Non-guessable; safe to embed in a URL.
        do {
            $token = bin2hex(random_bytes(32));
            $exists = Database::fetchOne(
                "SELECT id FROM employee_activation_codes WHERE token = ? LIMIT 1",
                [$token]
            );
        } while ($exists);
        return $token;
    }
}
