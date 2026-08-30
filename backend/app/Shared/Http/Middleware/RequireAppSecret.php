<?php

declare(strict_types=1);

namespace App\Shared\Http\Middleware;

use App\Exceptions\ApiFailure;
use App\Support\Value;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * The shared secret every published app build sends.
 *
 * HTTP Basic, carried by all four Flutter apps and the web client, so the API
 * cannot simply be called with curl by anyone who reads a URL out of a bundle.
 * It is not authentication — the per-principal guards do that — it is the
 * difference between an endpoint being reachable by our own clients and being
 * reachable by everything.
 *
 * Off when unset, which is how local development runs: the alternative would
 * make a fresh checkout answer 401 to everything with no clue why.
 */
final class RequireAppSecret
{
    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = Value::string(config('medjat.app_secret.user'));
        $key = Value::string(config('medjat.app_secret.key'));

        if ($user === '' || $key === '') {
            return $next($request);
        }

        // The scheduled jobs present their own secret instead. They are called
        // by curl from the crontab, which has no app bundle to take one from.
        if ($this->isCron($request)) {
            return $next($request);
        }

        [$providedUser, $providedKey] = $this->credentials($request);

        $ok = $providedUser !== null
            && hash_equals($user, $providedUser)
            && hash_equals($key, $providedKey ?? '');

        if (! $ok) {
            throw new ApiFailure('Unauthorized', 401, 'unauthorized');
        }

        return $next($request);
    }

    private function isCron(Request $request): bool
    {
        $expected = Value::string(config('medjat.cron.secret'));

        if ($expected === '') {
            return false;
        }

        $provided = Value::string($request->header('X-Cron-Secret'))
            ?: Value::string($request->query('cron_secret'))
            ?: Value::string($request->query('key'));

        return $provided !== '' && hash_equals($expected, $provided);
    }

    /**
     * @return array{0: string|null, 1: string|null}
     */
    private function credentials(Request $request): array
    {
        $user = $request->getUser();

        if ($user !== null) {
            return [$user, $request->getPassword()];
        }

        // The raw header, for deployments where the server does not populate
        // PHP_AUTH_* — it needs CGIPassAuth or a rewrite to reach PHP at all,
        // and one of the two is missing often enough to be worth handling.
        $header = Value::string($request->header('Authorization'));

        if (stripos($header, 'Basic ') !== 0) {
            return [null, null];
        }

        $decoded = base64_decode(substr($header, 6), true);

        if ($decoded === false || ! str_contains($decoded, ':')) {
            return [null, null];
        }

        [$decodedUser, $decodedKey] = explode(':', $decoded, 2);

        return [$decodedUser, $decodedKey];
    }
}
