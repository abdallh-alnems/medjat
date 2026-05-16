<?php

final class I18n {
    private static ?string $locale = null;
    private static ?array $strings = null;

    public static function setLocale(string $locale): void {
        self::$locale = in_array($locale, ['ar', 'en']) ? $locale : 'ar';
        self::$strings = null;
    }

    public static function getLocale(): string {
        return self::$locale ?? 'ar';
    }

    public static function t(string $key, ?array $params = null): string {
        if (self::$strings === null) {
            self::loadStrings();
        }

        $text = self::$strings[$key] ?? $key;

        if ($params) {
            foreach ($params as $k => $v) {
                $text = str_replace(":{$k}", (string) $v, $text);
            }
        }

        return $text;
    }

    private static function loadStrings(): void {
        $locale = self::getLocale();
        $file = __DIR__ . "/../lang/{$locale}.php";

        if (file_exists($file)) {
            self::$strings = require $file;
        } else {
            self::$strings = [];
        }
    }
}
