<?php

declare(strict_types=1);

namespace App\Modules\Auth\Services;

/**
 * Phone comparison for a dataset that is only mostly E.164.
 *
 * Numbers are stored as +201023809407 but a user types 01023809407, and some
 * legacy rows carry a country code with the local leading zero still attached
 * (+2001023809407). Comparing on digits alone would reject a correct code over
 * formatting, so the tail of the significant digits is what has to match.
 */
final class PhoneNumber
{
    public static function digits(string $phone): string
    {
        return preg_replace('/\D/', '', $phone) ?? '';
    }

    /**
     * Significant digits: no separators, no leading zeros, no country prefix
     * difference.
     */
    public static function core(string $phone): string
    {
        return ltrim(self::digits($phone), '0');
    }

    /**
     * True when two numbers plausibly denote the same line.
     *
     * Deliberately lenient. In every caller the secret is the activation code,
     * not the phone number — this is a sanity guard against typing the wrong
     * person's code, not an authentication factor.
     */
    public static function matches(string $a, string $b): bool
    {
        if (self::digits($a) === self::digits($b)) {
            return true;
        }

        $coreA = self::core($a);
        $coreB = self::core($b);

        if ($coreA === '' || $coreB === '') {
            return false;
        }

        return str_ends_with($coreA, $coreB) || str_ends_with($coreB, $coreA);
    }
}
