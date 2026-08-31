<?php

declare(strict_types=1);

namespace App\Shared\Http\Middleware;

use App\Modules\Kiosk\Domain\KioskStation;
use App\Modules\Kiosk\Domain\KioskToken;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * The third authentication principal.
 *
 * An administrator authenticates as a person, an employee as themselves, and a
 * kiosk as a branch. That last one is the reason this is separate rather than a
 * variation of the employee guard: a kiosk credential can produce attendance
 * for anyone enrolled at its branch, which is why it is bound to one branch,
 * revocable, hashed at rest, and why nothing here sets an employee.
 *
 * The lookup re-checks that the station is still active, so a partially applied
 * revocation fails closed rather than leaving a live tablet.
 */
final class AuthenticateKiosk
{
    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->header('X-Kiosk-Token') ?? $request->input('kiosk_token');

        if (! is_string($token) || $token === '') {
            return ApiResponse::fail('Kiosk token is required', 401);
        }

        $active = KioskToken::findActiveByPlain($token);

        if ($active === null) {
            // Translated, with the key carried separately: the tablet routes on
            // the code and shows the message to whoever is standing there.
            return ApiResponse::fail(__('messages.kiosk_token_invalid'), 401, 'kiosk_token_invalid');
        }

        $stationId = Value::int($active['station_id'] ?? null);

        $appVersion = $request->input('app_version');
        $appVersion = is_string($appVersion) && $appVersion !== '' ? substr($appVersion, 0, 20) : null;

        KioskStation::touchSeen($stationId, $request->ip(), $appVersion);
        KioskToken::touchUsed(Value::int($active['id'] ?? null));

        $request->attributes->set('kiosk', $active);
        $request->attributes->set('station_id', $stationId);
        $request->attributes->set('tenant_id', Value::int($active['tenant_id'] ?? null));
        $request->attributes->set('branch_id', Value::int($active['branch_id'] ?? null));

        return $next($request);
    }
}
