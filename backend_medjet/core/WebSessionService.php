<?php

/**
 * Browser sessions for employees.
 *
 * The app's session model cannot be reused here. An app token never expires,
 * which is defensible on a personal phone and indefensible on an office
 * computer: the next person to sit down would inherit it. So a browser session
 * has two ends — the employee's check-out, and a hard age limit — and getting a
 * new one costs a PIN rather than a call to HR.
 *
 * Sixteen hours is not a security parameter, it is a shift parameter: it has to
 * outlast a twelve-hour day plus overtime, or an employee who checked in cannot
 * check out. Ending at check-out is what actually keeps shared machines clean;
 * the age limit only catches the employee who forgot to close their day.
 */
final class WebSessionService {
    /** Covers a 12-hour shift plus overtime. See the class comment before shortening this. */
    public const LIFETIME_SECONDS = 16 * 3600;

    /**
     * Issues a session, ending any other browser session this employee holds.
     *
     * Scoped to the browser: signing in here must not log the employee out of
     * their phone. FR-005 is about one *browser* identity, and revoking the app
     * token would punish an employee for using a computer once.
     *
     * @return array{token: string, expires_at: ?string}
     */
    public static function issue(int $tenantId, int $employeeId, string $deviceId): array {
        return EmployeeAuthTokenModel::issueWeb(
            $tenantId,
            $employeeId,
            $deviceId,
            self::LIFETIME_SECONDS
        );
    }

    /** Ends the presenting session. Idempotent — logging out twice is a success, not an error. */
    public static function revokeCurrent(string $plainToken, string $reason = 'web_logout'): void {
        EmployeeAuthTokenModel::revokeByPlain($plainToken, $reason);
    }

    /**
     * Ends every browser session this employee holds.
     *
     * Called on check-out, so the shared computer is left safe by the system
     * rather than by the departing employee remembering to press a button — and
     * on an administrator PIN reset, where the point is that access stops *now*,
     * not at the next expiry.
     */
    public static function revokeAllForEmployee(int $employeeId, string $reason): void {
        EmployeeAuthTokenModel::revokeWebForEmployee($employeeId, $reason);
    }

    /** True when the presenting request is authenticated by a browser session rather than the app. */
    public static function isWebSession(array $auth): bool {
        return ($auth['platform'] ?? null) === 'web';
    }

    /** Requests one employee may make per minute on the browser channel. */
    private const PER_EMPLOYEE_LIMIT = 60;
    private const PER_EMPLOYEE_WINDOW = 60;

    /**
     * Bounds a single employee's traffic on the browser channel.
     *
     * `RateLimiter::enforceIpLimit()` cannot do this job here. Every browser
     * request reaches the backend through the web application's server-side
     * proxy — the backend Basic credentials must never be exposed to the page —
     * so REMOTE_ADDR is the *proxy's* address for every employee alike. The
     * per-IP limit is therefore a single shared bucket, and one misbehaving page
     * can drain it for the whole company. A React effect loop did exactly that
     * during testing: 600 requests a minute from one open tab.
     *
     * The employee id is the right key precisely because it cannot be forged
     * after authentication — unlike an address, which behind a proxy is either
     * everyone's or a header the client controls. Forwarding a client IP header
     * and trusting it was the alternative, and it was rejected: it invents a
     * trust relationship that one misconfiguration turns into a total bypass.
     * Coarse flood protection belongs in nginx, which sees the real address.
     *
     * Applies to browser sessions only — the mobile app talks to the backend
     * directly, so its address is genuine and its limits already work.
     */
    public static function enforcePerEmployeeLimit(array $auth): void {
        if (!self::isWebSession($auth)) {
            return;
        }

        $employeeId = (int) ($auth['employee_id'] ?? 0);
        if ($employeeId <= 0) {
            return;
        }

        if (!RateLimiter::checkLimit('web_emp:' . $employeeId, self::PER_EMPLOYEE_LIMIT, self::PER_EMPLOYEE_WINDOW)) {
            Response::rateLimited(self::PER_EMPLOYEE_WINDOW);
        }
    }

    /**
     * The token the current request presented, so it can be revoked.
     *
     * Mirrors Auth::authenticateEmployee's lookup order.
     */
    public static function currentToken(array $input = []): ?string {
        $token = $_SERVER['HTTP_X_EMPLOYEE_TOKEN']
            ?? $input['employee_token']
            ?? $_GET['employee_token']
            ?? null;

        return is_string($token) && $token !== '' ? $token : null;
    }
}
