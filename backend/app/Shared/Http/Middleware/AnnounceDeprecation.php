<?php

declare(strict_types=1);

namespace App\Shared\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

/**
 * Tells a caller that the URL it used is on its way out.
 *
 * The `.php` URLs exist because API_HOST is compiled into Flutter builds that
 * are already in the stores and on people's phones. A build from two years ago
 * still calls them, so they cannot be retired on a date we pick — only on a
 * date the traffic tells us is safe.
 *
 * That is what this is for. RFC 8594 headers announce the intent to every
 * client, and the sampled log answers the only question that matters before
 * deleting them: is anybody still calling this, and which one.
 *
 * Without the measurement, "we will remove them eventually" is a sentence
 * nobody can ever act on.
 */
final class AnnounceDeprecation
{
    /**
     * Sampling rate for the usage log.
     *
     * One in twenty. Enough to see which endpoints are still live and roughly
     * how busy, without writing a log line for every request the entire mobile
     * fleet makes.
     */
    private const SAMPLE = 20;

    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        $name = $request->route()?->getName();

        if ($name === null || ! str_starts_with($name, 'legacy.')) {
            return $response;
        }

        // Deliberately no Sunset date. Announcing one we cannot keep is worse
        // than announcing none: it is a promise to break somebody's phone on a
        // day chosen before we knew who was still calling.
        $response->headers->set('Deprecation', 'true');
        $response->headers->set('Link', '</v1>; rel="successor-version"');

        if (random_int(1, self::SAMPLE) === 1) {
            Log::channel('deprecated')->info('legacy endpoint', [
                'route' => $name,
                'path' => $request->path(),
                // Which app build is still on it — the number that decides when
                // the URL can go.
                'app_version' => $request->header('X-App-Version'),
                'platform' => $request->header('X-Platform'),
            ]);
        }

        return $response;
    }
}
