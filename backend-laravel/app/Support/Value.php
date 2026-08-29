<?php

declare(strict_types=1);

namespace App\Support;

/**
 * Narrowing helpers for values the query builder hands back as `mixed`.
 *
 * DB::table()->value() and the stdClass rows from ->first() are untyped by
 * construction, and a bare (int) cast on them is the thing static analysis
 * rightly objects to: it silently turns null into 0 and an unexpected array
 * into 1. These make the conversion explicit and total, so a wrong assumption
 * shows up as a default rather than as a nonsense number three layers away.
 */
final class Value
{
    public static function int(mixed $value, int $default = 0): int
    {
        return is_numeric($value) ? (int) $value : $default;
    }

    public static function float(mixed $value, float $default = 0.0): float
    {
        return is_numeric($value) ? (float) $value : $default;
    }

    public static function string(mixed $value, string $default = ''): string
    {
        return is_scalar($value) ? (string) $value : $default;
    }

    /**
     * Distinguishes "absent" from "empty", which matters for nullable columns:
     * a missing branch name is null, not ''.
     */
    public static function nullableString(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        return is_scalar($value) ? (string) $value : null;
    }

    public static function nullableInt(mixed $value): ?int
    {
        return is_numeric($value) ? (int) $value : null;
    }
}
