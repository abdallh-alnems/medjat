<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Exceptions\ApiFailure;
use App\Models\Admin;
use App\Services\Auth\FirebaseTokenVerifier;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Authenticates the management surfaces. Replaces Auth::authenticateUser().
 */
final class AuthenticateAdmin
{
    public function __construct(private readonly FirebaseTokenVerifier $verifier) {}

    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->header('X-Firebase-Token')
            ?? $request->input('token')
            ?? $request->query('token');

        if (! is_string($token) || $token === '') {
            throw new ApiFailure('Token is required', 400);
        }

        $identity = $this->verifier->verify($token);

        $admin = Admin::query()->where('firebase_uid', $identity->uid)->first();
        if ($admin === null) {
            throw new ApiFailure('Admin not found', 404);
        }

        if (! $admin->is_active) {
            // Removal no longer disables the account — it only detaches the
            // company — so an inactive account here is a genuine suspension.
            throw new ApiFailure('تم إيقاف حسابك من قِبل المسؤول', 403, 'account_deactivated');
        }

        $this->assertStillAMember($request, $admin);
        $this->assertNotSuperseded($request, $admin);

        $request->attributes->set('admin', $admin);
        $request->attributes->set('tenant_id', $admin->tenant_id);

        return $next($request);
    }

    /**
     * A detached administrator — removed from their company — whose app still
     * carries a stale company context. Refusing here makes the apps drop it and
     * return to onboarding, and stops a lingering session from touching a
     * company the person no longer belongs to.
     */
    private function assertStillAMember(Request $request, Admin $admin): void
    {
        $claimed = $request->header('X-Tenant-Id') ?? $request->input('tenant_id') ?? $request->query('tenant_id');

        $claimsATenant = is_scalar($claimed) && (string) $claimed !== '';

        if ($claimsATenant && $admin->tenant_id === null) {
            throw new ApiFailure('تمت إزالتك من الشركة من قِبل المسؤول', 403, 'account_removed');
        }
    }

    /**
     * One active session per administrator, most recent wins.
     *
     * Only enforced when both sides carry a device id, so builds predating the
     * header keep working until their next sign-in rather than being logged out
     * by an upgrade.
     */
    private function assertNotSuperseded(Request $request, Admin $admin): void
    {
        $deviceId = $request->header('X-Device-Id') ?? $request->input('device_id') ?? $request->query('device_id');

        if ($admin->active_device_id === null || $admin->active_device_id === '') {
            return;
        }

        if (! is_string($deviceId) || $deviceId === '') {
            return;
        }

        if ($admin->active_device_id !== $deviceId) {
            throw new ApiFailure('تم تسجيل الدخول من جهاز آخر', 401, 'session_superseded');
        }
    }
}
