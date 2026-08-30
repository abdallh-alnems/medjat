<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Domain\SuperAdmin\SuperAdminSession;
use App\Exceptions\ApiFailure;
use App\Support\Value;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * The support desk's own guard.
 *
 * A fourth principal beside the administrator, the employee and the kiosk, and
 * the only one not scoped to a company. It carries a bearer token from its own
 * session table rather than a Firebase credential, because the panel signs in
 * with a username and password that no company controls.
 */
final class AuthenticateSuperAdmin
{
    /**
     * @param  Closure(Request): Response  $next
     * @param  string  $minRole  readonly, admin or superadmin. Satisfied by that
     *                           rung or anything above it.
     */
    public function handle(Request $request, Closure $next, string $minRole = 'readonly'): Response
    {
        $token = Value::string($request->bearerToken());

        $admin = SuperAdminSession::resolve($token);

        if ($admin === null) {
            throw new ApiFailure('Admin token required', 401, 'admin_token_required');
        }

        if ($admin->is_active !== 1) {
            throw new ApiFailure('Admin account disabled', 403, 'admin_disabled');
        }

        if (! $admin->outranks($minRole)) {
            throw new ApiFailure('Insufficient permissions', 403, 'insufficient_permissions');
        }

        $request->attributes->set('super_admin', $admin);

        return $next($request);
    }
}
