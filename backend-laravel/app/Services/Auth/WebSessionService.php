<?php

declare(strict_types=1);

namespace App\Services\Auth;

use App\Models\EmployeeAuthToken;
use Illuminate\Http\Request;

/**
 * Browser sessions, which are deliberately not the same thing as app sessions.
 */
final class WebSessionService
{
    /**
     * Sixteen hours: long enough to cover the longest shift plus overtime, short
     * enough that a session left open on a shared branch computer is gone by the
     * next morning.
     */
    public const LIFETIME_SECONDS = 16 * 3600;

    /**
     * Issues a session, ending any other browser session this employee holds.
     *
     * Scoped to the browser on purpose: signing in here must not sign them out
     * of their phone. The rule is one browser identity, and revoking the app
     * token would punish someone for using a computer once.
     *
     * @return array{token: string, expires_at: string}
     */
    public static function issue(int $tenantId, int $employeeId, string $deviceId): array
    {
        return EmployeeAuthToken::issueWeb($tenantId, $employeeId, $deviceId, self::LIFETIME_SECONDS);
    }

    /** Ends the presenting session. Idempotent — logging out twice is a success. */
    public static function revokeCurrent(string $plainToken, string $reason = 'web_logout'): void
    {
        EmployeeAuthToken::revokeByPlain($plainToken, $reason);
    }

    /**
     * Ends every browser session this employee holds.
     *
     * Called on check-out, so a shared computer is left safe by the system
     * rather than by the departing employee remembering to press a button, and
     * on an administrator PIN reset, where the point is that access stops now
     * rather than at the next expiry.
     */
    public static function revokeAllForEmployee(int $employeeId, string $reason): void
    {
        EmployeeAuthToken::revokeForEmployee($employeeId, $reason, ['web']);
    }

    /**
     * The token the current request presented, so it can be revoked. Mirrors the
     * lookup order the employee guard uses.
     */
    public static function currentToken(Request $request): ?string
    {
        $token = $request->header('X-Employee-Token')
            ?? $request->input('employee_token')
            ?? $request->query('employee_token');

        return is_string($token) && $token !== '' ? $token : null;
    }
}
