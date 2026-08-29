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
     * Permissions that come free with a broader one.
     *
     * Documents were split into sub-permissions after the fact; anyone who could
     * already manage documents kept everything that used to be one permission,
     * rather than silently losing access on the day of the split.
     *
     * @var array<string, list<string>>
     */
    private const IMPLIED = [
        'manage_documents' => ['documents_manage_types', 'documents_verify', 'documents_view_reports'],
    ];

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

        if ($held === Permissions::ALL || $this->covers($held, $permission)) {
            return $next($request);
        }

        throw new ApiFailure("Missing permission: {$permission}", 403, 'missing_permission');
    }

    /**
     * @param  list<string>  $held
     */
    private function covers(array $held, string $permission): bool
    {
        if (in_array($permission, $held, true)) {
            return true;
        }

        foreach (self::IMPLIED as $broader => $implied) {
            if (in_array($broader, $held, true) && in_array($permission, $implied, true)) {
                return true;
            }
        }

        return false;
    }
}
