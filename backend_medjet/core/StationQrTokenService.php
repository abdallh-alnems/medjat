<?php

final class StationQrTokenService {
    private static function secret(): string {
        $s = getenv('JWT_SECRET');
        if (!$s || strlen($s) < 32) {
            error_log('CRITICAL: JWT_SECRET is missing or too short');
            Response::fail('Server misconfigured: JWT_SECRET missing', 500);
        }
        return $s;
    }

    public static function generate(int $employeeId, int $tenantId, int $branchId): string {
        $payload = [
            'eid' => $employeeId,
            'tid' => $tenantId,
            'bid' => $branchId,
            'exp' => time() + 30,
            'rnd' => bin2hex(random_bytes(4)),
        ];
        $json = json_encode($payload, JSON_UNESCAPED_UNICODE);
        $iv = random_bytes(openssl_cipher_iv_length('aes-256-cbc'));
        $encrypted = openssl_encrypt($json, 'aes-256-cbc', self::secret(), OPENSSL_RAW_DATA, $iv);
        $hmac = hash_hmac('sha256', $iv . $encrypted, self::secret(), true);
        return base64_encode($hmac . $iv . $encrypted);
    }

    public static function verify(string $token): ?array {
        $decoded = base64_decode($token, true);
        if ($decoded === false || strlen($decoded) < 64) return null;

        $hmac = substr($decoded, 0, 32);
        $iv = substr($decoded, 32, 16);
        $encrypted = substr($decoded, 48);

        $expectedHmac = hash_hmac('sha256', $iv . $encrypted, self::secret(), true);
        if (!hash_equals($expectedHmac, $hmac)) return null;

        $json = openssl_decrypt($encrypted, 'aes-256-cbc', self::secret(), OPENSSL_RAW_DATA, $iv);
        if ($json === false) return null;

        $payload = json_decode($json, true);
        if (!$payload) return null;

        if (isset($payload['exp']) && $payload['exp'] < time()) return null;

        return [
            'employee_id' => (int) ($payload['eid'] ?? 0),
            'tenant_id' => (int) ($payload['tid'] ?? 0),
            'branch_id' => (int) ($payload['bid'] ?? 0),
        ];
    }
}
