<?php

/**
 * The wire format spoken by ZKTeco "push" (ADMS) terminals.
 *
 * Pure parsing and formatting — no database, no side effects — because the one
 * thing that always needs adjusting for a new firmware revision is this layer,
 * and it has to be testable without a device on the desk.
 *
 * Shape of the conversation (the device always dials out):
 *   GET  /iclock/cdata?SN=..&options=all&pushver=..   handshake, we answer config
 *   POST /iclock/cdata?SN=..&table=ATTLOG             punches      -> "OK"
 *   POST /iclock/cdata?SN=..&table=OPERLOG            users/events -> "OK"
 *   GET  /iclock/getrequest?SN=..                     command poll -> "OK" or C:..
 *   POST /iclock/devicecmd?SN=..                      command result
 */
final class ZktecoAdms {
    /** Verify modes reported in ATTLOG, mapped to our recognition_method values. */
    private const VERIFY_MODES = [
        0 => 'device_password',
        1 => 'device_fingerprint',
        2 => 'device_fingerprint',
        3 => 'device_card',
        4 => 'device_card',
        15 => 'device_face',
        16 => 'device_face',
    ];

    public static function recognitionMethod(?int $verifyMode): string {
        if ($verifyMode === null) {
            return 'device_fingerprint';
        }
        return self::VERIFY_MODES[$verifyMode] ?? 'device_fingerprint';
    }

    /**
     * Parses one ATTLOG line: PIN \t time \t status \t verify \t workcode \t ...
     *
     * Returns null for anything unparseable rather than throwing — one bad line
     * in a batch of 500 must not cost us the other 499.
     */
    public static function parseAttlogLine(string $line): ?array {
        $line = trim($line, "\r\n");
        if ($line === '') {
            return null;
        }

        // Firmware is inconsistent about the separator: tabs are the spec, but
        // some builds emit runs of spaces.
        $parts = preg_split('/\t+/', $line);
        if ($parts === false || count($parts) < 2) {
            $parts = preg_split('/\s{2,}/', $line);
        }
        if ($parts === false || count($parts) < 2) {
            return null;
        }

        $pin = trim($parts[0]);
        $time = trim($parts[1]);
        if ($pin === '' || $time === '') {
            return null;
        }

        $timestamp = self::parseDateTime($time);
        if ($timestamp === null) {
            return null;
        }

        return [
            'pin' => $pin,
            'punched_at' => $timestamp,
            'status' => isset($parts[2]) && $parts[2] !== '' ? (int) $parts[2] : null,
            'verify' => isset($parts[3]) && $parts[3] !== '' ? (int) $parts[3] : null,
            'work_code' => isset($parts[4]) && trim($parts[4]) !== '' ? substr(trim($parts[4]), 0, 16) : null,
            'raw' => substr($line, 0, 255),
        ];
    }

    /**
     * Normalises the device's timestamp to 'Y-m-d H:i:s'.
     *
     * The value is the terminal's own wall clock. It is NOT converted to any
     * timezone here: the device stands at the branch, so its clock already is
     * the company's local time — the same frame the attendance table uses.
     */
    public static function parseDateTime(string $value): ?string {
        $value = trim($value);
        if (preg_match('/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?$/', $value, $m)) {
            return sprintf(
                '%04d-%02d-%02d %02d:%02d:%02d',
                $m[1], $m[2], $m[3], $m[4], $m[5], $m[6] ?? 0
            );
        }
        $ts = strtotime($value);
        return $ts === false ? null : date('Y-m-d H:i:s', $ts);
    }

    /**
     * Parses an OPERLOG line. Only USER lines carry anything we want (the
     * device's own user list); the rest are acknowledged and dropped.
     */
    public static function parseOperlogLine(string $line): ?array {
        $line = trim($line, "\r\n");
        if ($line === '') {
            return null;
        }

        if (stripos($line, 'USER ') === 0) {
            $fields = self::parseFields(substr($line, 5));
            $pin = $fields['PIN'] ?? $fields['pin'] ?? null;
            if ($pin === null || trim((string) $pin) === '') {
                return null;
            }
            return [
                'kind' => 'user',
                'pin' => trim((string) $pin),
                'name' => self::cleanName($fields['Name'] ?? $fields['name'] ?? null),
                'card' => self::cleanValue($fields['Card'] ?? $fields['card'] ?? null),
                'privilege' => isset($fields['Pri']) && $fields['Pri'] !== '' ? (int) $fields['Pri'] : null,
            ];
        }

        // FP / FACE / BIOPHOTO / USERPIC carry biometric templates. They are
        // megabytes of base64 that belong to the device, not to us — matching
        // happens on the terminal.
        foreach (['FP ', 'FACE ', 'BIOPHOTO ', 'USERPIC ', 'BIODATA '] as $prefix) {
            if (stripos($line, $prefix) === 0) {
                return ['kind' => 'biometric'];
            }
        }

        return ['kind' => 'other'];
    }

    /** Splits `KEY=value\tKEY=value` into an associative array. */
    public static function parseFields(string $payload): array {
        $out = [];
        foreach (preg_split('/\t+/', $payload) ?: [] as $chunk) {
            $chunk = trim($chunk);
            if ($chunk === '' || strpos($chunk, '=') === false) {
                continue;
            }
            [$k, $v] = explode('=', $chunk, 2);
            $out[trim($k)] = trim($v);
        }
        return $out;
    }

    private static function cleanName($value): ?string {
        $value = self::cleanValue($value);
        if ($value === null) {
            return null;
        }
        // Terminals pad short names with NULs and often store mojibake for
        // non-ASCII; keep what is printable and let HR fix the rest.
        $value = trim(str_replace("\0", '', $value));
        return $value === '' ? null : mb_substr($value, 0, 100);
    }

    private static function cleanValue($value): ?string {
        if ($value === null) {
            return null;
        }
        $value = trim((string) $value);
        if ($value === '' || $value === '0') {
            return null;
        }
        return $value;
    }

    /**
     * The configuration block returned on the handshake.
     *
     * `Realtime=1` is the line that matters: it tells the terminal to push each
     * punch as it happens instead of waiting for the batch window. `Stamp` is
     * the device's transfer cursor — answering with the device's own value
     * keeps it from re-sending everything it has ever recorded.
     */
    public static function handshakeResponse(string $serial, int $timezoneOffsetHours, array $stamps = []): string {
        $lines = [
            'GET OPTION FROM: ' . $serial,
            'Stamp=' . ($stamps['ATTLOG'] ?? '9999'),
            'OpStamp=' . ($stamps['OPERLOG'] ?? '9999'),
            'ErrorDelay=30',
            'Delay=10',
            'TransTimes=00:00;14:05',
            'TransInterval=1',
            'TransFlag=1111000000',
            'Realtime=1',
            'TimeZone=' . $timezoneOffsetHours,
            'Encrypt=0',
        ];
        return implode("\r\n", $lines) . "\r\n";
    }

    /**
     * ZK's packed datetime: a single integer counting seconds in a calendar
     * where every month has 31 days. Used by `SET OPTIONS DateTime`.
     */
    public static function encodeDateTime(int $year, int $month, int $day, int $hour, int $minute, int $second): int {
        return (($year - 2000) * 12 * 31 + ($month - 1) * 31 + ($day - 1)) * 86400
            + $hour * 3600 + $minute * 60 + $second;
    }

    /** Builds the command line for a queued command kind. */
    public static function commandPayload(string $kind, array $context = []): ?string {
        switch ($kind) {
            case 'sync_time':
                $now = $context['now'] ?? null; // 'Y-m-d H:i:s' in company local time
                if (!$now) {
                    return null;
                }
                $t = strtotime($now);
                $encoded = self::encodeDateTime(
                    (int) date('Y', $t), (int) date('n', $t), (int) date('j', $t),
                    (int) date('G', $t), (int) date('i', $t), (int) date('s', $t)
                );
                return 'SET OPTIONS DateTime=' . $encoded;
            case 'reboot':
                return 'REBOOT';
            case 'info':
                return 'INFO';
            case 'delete_user':
                $pin = $context['pin'] ?? null;
                return $pin === null ? null : 'DATA DELETE USERINFO PIN=' . $pin;
            default:
                return null;
        }
    }

    /** Renders queued commands into the body the device expects. */
    public static function commandResponse(array $commands): string {
        if (!$commands) {
            return 'OK';
        }
        $lines = [];
        foreach ($commands as $c) {
            $lines[] = 'C:' . $c['id'] . ':' . $c['payload'];
        }
        return implode("\r\n", $lines) . "\r\n";
    }
}
