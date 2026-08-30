<?php

declare(strict_types=1);

namespace App\Shared\Contact;

/**
 * Normalises a phone number to E.164, or refuses it.
 *
 * A country code is mandatory. A bare national number is ambiguous across the
 * markets this serves — Egypt, the Gulf and the wider region — and storing one
 * makes every later phone-matched lookup unreliable. Refusing at the write path
 * is the only place the ambiguity can still be resolved by asking.
 *
 * Arabic-Indic digits are accepted because the keyboards in this market produce
 * them, and "00<cc>" is accepted because it is how the region writes "+<cc>".
 */
final class PhoneValidator
{
    private const ARABIC_INDIC = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    private const ASCII = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    public static function normalize(string $phone): ?string
    {
        $value = trim(str_replace(self::ARABIC_INDIC, self::ASCII, $phone));

        if (str_starts_with($value, '00')) {
            $value = '+'.substr($value, 2);
        }

        if (! str_starts_with($value, '+')) {
            return null;
        }

        $digits = preg_replace('/\D/', '', $value) ?? '';
        $normalized = '+'.$digits;

        // E.164: a leading country digit of 1-9, then 7 to 14 more.
        //
        // Note this cannot catch a national leading zero left inside a country
        // code (+2001023809407 is well-formed and wrong). Legacy rows in that
        // shape exist; anything matching on phone has to tolerate them, which
        // is what PhoneNumber::matches() is for.
        return preg_match('/^\+[1-9]\d{7,14}$/', $normalized) === 1 ? $normalized : null;
    }
}
