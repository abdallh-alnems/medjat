<?php

declare(strict_types=1);

namespace App\Shared\Http\Middleware;

use App\Exceptions\ApiFailure;
use App\Support\Value;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

/**
 * Establishes which company a request acts on, and that it may.
 *
 * The tenant comes from the authenticated session — set by AuthenticateAdmin or
 * AuthenticateEmployee — never from the request. A caller who could name their
 * own tenant could read any company's data by asking for it, which is the whole
 * of multi-tenant isolation in one sentence.
 */
final class RequireTenant
{
    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));

        if ($tenantId <= 0) {
            throw new ApiFailure('Tenant ID is required', 400);
        }

        $tenant = DB::table('tenants')->where('id', $tenantId)->first(['id', 'is_active']);

        if ($tenant === null) {
            throw new ApiFailure(__('messages.tenant_not_found'), 404);
        }

        if (! Value::int($tenant->is_active)) {
            throw new ApiFailure(__('messages.company_suspended'), 403);
        }

        return $next($request);
    }
}
