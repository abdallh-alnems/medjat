<?php

declare(strict_types=1);

namespace App\Domain\Auth;

use Illuminate\Support\Facades\Config;

/**
 * Routes Firebase's action link through our own branded page.
 *
 * Only the base URL is swapped; Firebase's query string (mode, oobCode, apiKey,
 * lang) is carried across untouched, so this needs no change in the Firebase
 * console — and the page it lands on is the one that enforces the app's
 * password rules, which Firebase's default handler does not.
 *
 * Shared by the self-service reset and the one an operator sends on somebody's
 * behalf: two links that behaved differently would mean two password policies.
 */
final class AuthActionLink
{
    public static function rebase(string $link): string
    {
        $base = Config::string('medjat.mail.action_url');
        $query = parse_url($link, PHP_URL_QUERY);

        if ($base === '' || ! is_string($query) || $query === '') {
            return $link;
        }

        return $base.(str_contains($base, '?') ? '&' : '?').$query;
    }
}
