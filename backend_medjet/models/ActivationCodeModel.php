<?php

final class ActivationCodeModel {
    private const CODE_LENGTH = 6;
    private const VALIDITY_HOURS = 24;

    public static function generate(int $tenantId, int $employeeId): string {
        self::invalidateExistingForEmployee($employeeId);

        $code = self::generateUniqueCode();
        $expiresAt = date('Y-m-d H:i:s', strtotime('+' . self::VALIDITY_HOURS . ' hours'));

        Database::execute(
            "INSERT INTO employee_activation_codes (tenant_id, employee_id, code, expires_at)
             VALUES (?, ?, ?, ?)",
            [$tenantId, $employeeId, $code, $expiresAt]
        );

        return $code;
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

    public static function markUsed(int $codeId, string $firebaseUid): void {
        Database::execute(
            "UPDATE employee_activation_codes
             SET used_at = NOW(), used_by_firebase_uid = ?
             WHERE id = ?",
            [$firebaseUid, $codeId]
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
}
