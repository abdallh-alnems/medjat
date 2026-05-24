<?php

final class Validator {
    public static function sanitizeInput($input) {
        if (is_array($input)) {
            return array_map([self::class, 'sanitizeInput'], $input);
        }
        return is_string($input) ? trim($input) : $input;
    }

    public static function required($value, string $fieldName): void {
        if (empty($value) && $value !== '0' && $value !== 0) {
            Response::fail("{$fieldName} is required", 400);
        }
    }

    public static function numeric($value, string $fieldName, float $min = 0): float {
        if (!is_numeric($value) || (float) $value < $min) {
            Response::fail("Valid {$fieldName} is required", 400);
        }
        return (float) $value;
    }

    public static function maxLength(string $value, int $max, string $fieldName): string {
        if (mb_strlen($value) > $max) {
            Response::fail("{$fieldName} must be at most {$max} characters", 400);
        }
        return $value;
    }

    public static function enum(string $value, array $allowed, string $fieldName): string {
        if (!in_array($value, $allowed, true)) {
            Response::fail("Invalid {$fieldName}", 400);
        }
        return $value;
    }

    /**
     * Normalize an international phone number to E.164 (e.g. +966501234567).
     * The number must carry a country code: it has to start with "+" (or the
     * "00" international prefix). Returns null when it is not a valid E.164
     * number. Used as the login identity, so the format must be unambiguous.
     */
    public static function phone(string $phone): ?string {
        $arabic = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
        $english = ['0','1','2','3','4','5','6','7','8','9'];
        $value = trim(str_replace($arabic, $english, $phone));

        // "00<cc>..." is an alias for "+<cc>...".
        if (str_starts_with($value, '00')) {
            $value = '+' . substr($value, 2);
        }

        // A country code is mandatory; bare national numbers are ambiguous.
        if (!str_starts_with($value, '+')) {
            return null;
        }

        $normalized = '+' . preg_replace('/\D/', '', $value);

        // E.164: leading country digit 1-9, then 7-14 more digits (8-15 total).
        return preg_match('/^\+[1-9]\d{7,14}$/', $normalized) ? $normalized : null;
    }

    public static function date(string $value, string $fieldName): string {
        $date = DateTime::createFromFormat('Y-m-d', $value);
        if (!$date || $date->format('Y-m-d') !== $value) {
            Response::fail("Invalid {$fieldName} date format. Use Y-m-d", 400);
        }
        return $value;
    }

    public static function time(string $value, string $fieldName): string {
        if (!preg_match('/^([01]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$/', $value)) {
            Response::fail("Invalid {$fieldName} time format. Use H:i or H:i:s", 400);
        }
        return $value;
    }

    public static function getField(string $field, $default = null) {
        $value = $_POST[$field] ?? $_GET[$field] ?? $default;
        return self::sanitizeInput($value);
    }

    public static function getJsonBody(): array {
        static $body = null;
        if ($body === null) {
            $raw = file_get_contents('php://input');
            $body = json_decode($raw, true) ?: [];
        }
        return $body;
    }

    public static function getJsonField(string $field, $default = null) {
        return self::getJsonBody()[$field] ?? $default;
    }

    public static function getCombinedField(string $field, $default = null) {
        $jsonVal = self::getJsonField($field);
        if ($jsonVal !== null) return $jsonVal;
        return self::getField($field, $default);
    }
}
