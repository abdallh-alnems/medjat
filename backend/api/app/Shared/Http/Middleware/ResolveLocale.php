<?php

declare(strict_types=1);

namespace App\Shared\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Answers in the language the caller asked for.
 *
 * Until this existed the locale was whatever APP_LOCALE said — Arabic — for
 * every request from every client. The translation files were there and the
 * `__()` calls were there; nothing ever chose between them, which is why most
 * error messages ended up written inline in whichever language the author was
 * thinking in. The employee app, the management app and the web port all ship
 * English, and all three were being answered in Arabic.
 *
 * Accept-Language is the header clients already send, so nothing has to be
 * taught a new convention. Anything outside the two languages we actually have
 * falls back to the configured default rather than to a missing-key string.
 */
final class ResolveLocale
{
    /** The languages we have complete files for. */
    private const SUPPORTED = ['ar', 'en'];

    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $locale = $this->preferred($request);

        if ($locale !== null) {
            app()->setLocale($locale);
        }

        return $next($request);
    }

    /**
     * The first language in the header we can actually serve.
     *
     * Quality values are honoured because a browser sending "en;q=0.9, ar;q=1.0"
     * means it, and taking the leftmost entry would get it backwards.
     */
    private function preferred(Request $request): ?string
    {
        $header = $request->header('Accept-Language');

        if (! is_string($header) || trim($header) === '') {
            return null;
        }

        $ranked = [];

        foreach (explode(',', $header) as $part) {
            $bits = explode(';q=', trim($part));
            $tag = strtolower(trim($bits[0]));
            // "ar-EG" and "ar" are the same file to us.
            $tag = explode('-', $tag)[0];

            if (! in_array($tag, self::SUPPORTED, true)) {
                continue;
            }

            $q = isset($bits[1]) ? (float) $bits[1] : 1.0;
            $ranked[$tag] = max($ranked[$tag] ?? 0.0, $q);
        }

        if ($ranked === []) {
            return null;
        }

        arsort($ranked);

        return (string) array_key_first($ranked);
    }
}
