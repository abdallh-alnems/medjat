<?php

declare(strict_types=1);

namespace App\Domain\Access;

/**
 * What makes a six-digit browser PIN acceptable.
 *
 * Six digits is a small space, so the rules matter more than usual: they are
 * what stands between the channel and the few thousand PINs that appear at the
 * top of every cracking dictionary.
 */
final class PinPolicy
{
    public const LENGTH = 6;

    /**
     * The handful that are neither runs nor repeated blocks — people reach for
     * them because they are easy to type on a keypad, not because they follow a
     * rule, so they have to be listed.
     *
     * @var list<string>
     */
    private const BANNED = ['123456', '654321', '012345', '543210', '112233', '696969', '123321'];

    /**
     * Why a PIN was rejected, or null when it is acceptable.
     *
     * Returns a reason rather than a boolean so the interface can say what is
     * wrong: an employee told only that their choice "failed" will try another
     * guessable one.
     *
     * @param  string|null  $employeePhone  Their number, if known at this point.
     * @return null|'length'|'repeated'|'sequence'|'pattern'|'common'|'phone'
     */
    public static function rejectReason(?string $pin, ?string $employeePhone = null): ?string
    {
        if (! is_string($pin) || preg_match('/^\d{'.self::LENGTH.'}$/', $pin) !== 1) {
            return 'length';
        }

        // 000000, 111111 …
        if (preg_match('/^(\d)\1+$/', $pin) === 1) {
            return 'repeated';
        }

        if (self::isRun($pin)) {
            return 'sequence';
        }

        if (self::isRepeatedBlock($pin)) {
            return 'pattern';
        }

        if (in_array($pin, self::BANNED, true)) {
            return 'common';
        }

        // The phone number is the *username* on this channel. A PIN taken from
        // it is guessable by anyone who already knows the one thing they must
        // know to attack the account at all, which makes it the single worst
        // choice available — and a common one.
        if (is_string($employeePhone) && $employeePhone !== '') {
            $digits = preg_replace('/\D/', '', $employeePhone) ?? '';
            if ($digits !== '' && str_contains($digits, $pin)) {
                return 'phone';
            }
        }

        return null;
    }

    public static function isAcceptable(?string $pin, ?string $employeePhone = null): bool
    {
        return self::rejectReason($pin, $employeePhone) === null;
    }

    /**
     * Any run of consecutive digits in either direction — 123456, 234567,
     * 987654. Checked structurally rather than listed, because a list of "the
     * obvious ones" always misses the run that starts one digit over.
     */
    private static function isRun(string $pin): bool
    {
        $ascending = true;
        $descending = true;

        for ($i = 1; $i < self::LENGTH; $i++) {
            $step = (int) $pin[$i] - (int) $pin[$i - 1];
            $ascending = $ascending && $step === 1;
            $descending = $descending && $step === -1;
        }

        return $ascending || $descending;
    }

    /**
     * A short block repeated to fill the length: 121212, 123123. These read as
     * random to the person choosing them and are near the top of every cracking
     * dictionary.
     */
    private static function isRepeatedBlock(string $pin): bool
    {
        foreach ([2, 3] as $blockLength) {
            $block = substr($pin, 0, $blockLength);
            if ($pin === str_repeat($block, intdiv(self::LENGTH, $blockLength))) {
                return true;
            }
        }

        return false;
    }

    /**
     * The message shown for each reason. Arabic-first, because the employee
     * surface is.
     */
    public static function message(string $reason): string
    {
        return match ($reason) {
            'length' => 'الرقم السري يجب أن يكون ٦ أرقام',
            'repeated' => 'لا يمكن استخدام رقم مكرر مثل ١١١١١١',
            'sequence' => 'لا يمكن استخدام أرقام متتابعة مثل ١٢٣٤٥٦',
            'pattern' => 'لا يمكن استخدام نمط متكرر مثل ١٢١٢١٢',
            'common' => 'هذا الرقم السري شائع جدًا، اختر رقمًا آخر',
            'phone' => 'لا يمكن أن يكون الرقم السري جزءًا من رقم هاتفك',
            default => 'الرقم السري غير صالح',
        };
    }
}
