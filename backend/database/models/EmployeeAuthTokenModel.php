<?php

final class EmployeeAuthTokenModel {
    /** Platforms that represent the mobile app, as opposed to the browser. */
    private const APP_PLATFORMS = ['android', 'ios'];

    /**
     * The employee's active token for a channel.
     *
     * Since browser sessions arrived, an employee can legitimately hold two
     * tokens at once — one on their phone, one in a browser — so "the active
     * token" is only meaningful per channel. Callers that mean the app must say
     * so, otherwise a phone login could revoke the browser session and leave the
     * old phone token alive.
     *
     * @param string[]|null $platforms Restrict to these platforms; null = any.
     */
    public static function findActiveForEmployee(int $employeeId, ?array $platforms = null): ?array {
        $sql = "SELECT id, tenant_id, employee_id, device_id, device_model, platform,
                       app_version, issued_at, last_used_at, expires_at
                FROM employee_auth_tokens
                WHERE employee_id = ? AND revoked_at IS NULL
                  AND (expires_at IS NULL OR expires_at > NOW())";
        $params = [$employeeId];

        if ($platforms !== null && $platforms !== []) {
            $sql .= ' AND platform IN (' . implode(',', array_fill(0, count($platforms), '?')) . ')';
            $params = array_merge($params, $platforms);
        }

        return Database::fetchOne($sql . ' LIMIT 1', $params);
    }

    public static function issue(int $tenantId, int $employeeId, string $deviceId, ?string $deviceModel, string $platform, ?string $appVersion): string {
        // Scoped to the app platforms so that signing in on a phone does not
        // end an active browser session, and vice versa. Behaviour for the app
        // itself is unchanged: it has only ever held one token.
        self::revokeForEmployee($employeeId, 'reissued_on_login', self::APP_PLATFORMS);

        $plain = bin2hex(random_bytes(32));
        $hash = hash('sha256', $plain);

        Database::execute(
            "INSERT INTO employee_auth_tokens (tenant_id, employee_id, token_hash, device_id, device_model, platform, app_version)
             VALUES (?, ?, ?, ?, ?, ?, ?)",
            [$tenantId, $employeeId, $hash, $deviceId, $deviceModel, $platform, $appVersion]
        );

        return $plain;
    }

    /**
     * Issues a browser session: expiring, and one per employee.
     *
     * `expires_at` is computed **in SQL**. PHP runs UTC on the server while
     * MySQL runs the server zone, so a PHP-computed expiry is born hours wrong —
     * the face-challenge table learned this the hard way.
     *
     * @return array{token: string, expires_at: string}
     */
    public static function issueWeb(int $tenantId, int $employeeId, string $deviceId, int $lifetimeSeconds): array {
        self::revokeForEmployee($employeeId, 'reissued_on_web_login', ['web']);

        $plain = bin2hex(random_bytes(32));
        $hash = hash('sha256', $plain);

        Database::execute(
            "INSERT INTO employee_auth_tokens
                (tenant_id, employee_id, token_hash, device_id, platform, expires_at)
             VALUES (?, ?, ?, ?, 'web', DATE_ADD(NOW(), INTERVAL ? SECOND))",
            [$tenantId, $employeeId, $hash, $deviceId, $lifetimeSeconds]
        );

        $row = Database::fetchOne(
            'SELECT expires_at FROM employee_auth_tokens WHERE token_hash = ? LIMIT 1',
            [$hash]
        );

        return ['token' => $plain, 'expires_at' => $row['expires_at'] ?? null];
    }

    public static function findActiveByPlain(string $plain): ?array {
        $hash = hash('sha256', $plain);
        // An expired token is as dead as a revoked one. The comparison happens
        // in SQL against the database's own clock — comparing in PHP would use
        // UTC and quietly accept sessions for hours after they should have
        // ended, which is precisely the shared-device hole the expiry exists to
        // close. NULL still means "never expires", which is every app token.
        $row = Database::fetchOne(
            "SELECT id, tenant_id, employee_id, device_id, platform, expires_at
             FROM employee_auth_tokens
             WHERE token_hash = ?
               AND revoked_at IS NULL
               AND (expires_at IS NULL OR expires_at > NOW())
             LIMIT 1",
            [$hash]
        );

        if ($row) {
            Database::execute(
                "UPDATE employee_auth_tokens SET last_used_at = NOW() WHERE id = ?",
                [$row['id']]
            );
        }

        return $row;
    }

    public static function revokeByPlain(string $plain, string $reason): void {
        $hash = hash('sha256', $plain);
        Database::execute(
            "UPDATE employee_auth_tokens
             SET revoked_at = NOW(), revoke_reason = ?
             WHERE token_hash = ? AND revoked_at IS NULL",
            [$reason, $hash]
        );
    }

    /**
     * Revokes the employee's live tokens, optionally only on some platforms.
     *
     * Revokes **every** matching row rather than the first one found. With two
     * channels in play, "revoke the one active token" is no longer a safe
     * assumption, and a stray survivor is exactly the kind of thing that never
     * fails visibly.
     *
     * @param string[]|null $platforms null = every platform.
     * @return int Number of tokens revoked.
     */
    public static function revokeForEmployee(int $employeeId, string $reason, ?array $platforms = null): int {
        $sql = "UPDATE employee_auth_tokens
                SET revoked_at = NOW(), revoke_reason = ?
                WHERE employee_id = ? AND revoked_at IS NULL";
        $params = [$reason, $employeeId];

        if ($platforms !== null && $platforms !== []) {
            $sql .= ' AND platform IN (' . implode(',', array_fill(0, count($platforms), '?')) . ')';
            $params = array_merge($params, $platforms);
        }

        return Database::execute($sql, $params);
    }

    /** Ends every browser session for this employee — used on check-out and on PIN reset. */
    public static function revokeWebForEmployee(int $employeeId, string $reason): int {
        return self::revokeForEmployee($employeeId, $reason, ['web']);
    }
}
