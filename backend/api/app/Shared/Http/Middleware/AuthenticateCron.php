<?php

declare(strict_types=1);

namespace App\Shared\Http\Middleware;

use App\Exceptions\ApiFailure;
use App\Support\Value;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * The shared secret the scheduled jobs authenticate with.
 *
 * These endpoints terminate employees and delete photographs, so an unset
 * secret refuses everything rather than accepting anything — the opposite
 * default would turn a missing environment variable into an open door.
 *
 * Both parameter names are accepted because the installed crontab passes both;
 * changing that is a server edit, and the rule here is that the code adapts to
 * what is deployed rather than the other way round.
 */
final class AuthenticateCron
{
    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $expected = Value::string(config('medjat.cron.secret'));

        $provided = Value::string($request->query('key'))
            ?: Value::string($request->query('cron_secret'))
            ?: Value::string($request->input('key'))
            ?: Value::string($request->input('cron_secret'));

        // hash_equals rather than ===: the comparison happens on every
        // unauthenticated request that reaches these URLs.
        if ($expected === '' || ! hash_equals($expected, $provided)) {
            throw new ApiFailure('Forbidden', 403, 'forbidden');
        }

        return $next($request);
    }
}
