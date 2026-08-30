<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Domain\Access\Permissions;
use App\Exceptions\ApiFailure;
use App\Models\Admin;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Refuses a request the signed-in administrator does not hold the permission for.
 *
 * These guards have to agree with what the clients gate their navigation on. A
 * tab shown to somebody who cannot open it does not fail politely — it produces
 * a 403 here that the apps render as "an error occurred", which is the least
 * useful thing a person can be told.
 */
final class RequirePermission
{
    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next, string $permission): Response
    {
        $admin = $request->attributes->get('admin');

        if (! $admin instanceof Admin) {
            throw new ApiFailure('Authentication required', 401);
        }

        $held = Permissions::effectiveFor($admin->id, $admin->tenant_id ?? 0, $admin->role);

        if ($held === Permissions::ALL || Permissions::covers($held, $permission)) {
            return $next($request);
        }

        throw new ApiFailure("Missing permission: {$permission}", 403, 'missing_permission');
    }
}
