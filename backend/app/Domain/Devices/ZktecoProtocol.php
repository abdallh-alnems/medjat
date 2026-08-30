<?php

declare(strict_types=1);

namespace App\Domain\Devices;

use App\Support\Value;
use DateTimeImmutable;

/**
 * The dialect ZKTeco terminals speak.
 *
 * How a verify code maps to a recognition method, what a queued command looks
 * like on the wire, and how to read the two payloads a terminal uploads.
 */
final class ZktecoProtocol
{
    /**
     * How the person was recognised, by the device's verify code.
     *
     * Unknown codes fall back to a fingerprint rather than to null, because a
     * fingerprint is what these devices overwhelmingly are and an unrecorded
     * method reads as "we do not know how this punch happened".
     *
     * @var array<int, string>
     */
    private const VERIFY_MODES = [
        0 => 'device_password',
        1 => 'device_fingerprint',
        2 => 'device_fingerprint',
        3 => 'device_card',
        4 => 'device_card',
        15 => 'device_face',
        16 => 'device_face',
    ];

    /** Commands a company may queue, and what they mean on the wire. */
    public const COMMAND_KINDS = ['sync_time', 'reboot', 'info'];

    public static function recognitionMethod(?int $verifyMode): string
    {
        if ($verifyMode === null) {
            return 'device_fingerprint';
        }

        return self::VERIFY_MODES[$verifyMode] ?? 'device_fingerprint';
    }

    /**
     * @param  array<string, mixed>  $context
     */
    public static function commandPayload(string $kind, array $context = []): ?string
    {
        $now = Value::string($context['now'] ?? null);

        return match ($kind) {
            // The company's local time, not the server's: sending a UTC clock
            // to a terminal shifts every punch it records by the offset.
            'sync_time' => $now === '' ? null : 'SET OPTIONS DateTime='.self::encodeDateTime($now),
            'reboot' => 'REBOOT',
            'info' => 'INFO',
            default => null,
        };
    }

    /**
     * ZKTeco encodes a timestamp as one integer.
     *
     * Every month is treated as 31 days, which is the firmware's arithmetic and
     * not a bug here: the device decodes it with the same formula, so the two
     * agree even though the number means nothing on its own.
     */
    public static function encodeDateTime(string $timestamp): int
    {
        $at = strtotime($timestamp);

        if ($at === false) {
            return 0;
        }

        $year = (int) date('Y', $at);
        $month = (int) date('n', $at);
        $day = (int) date('j', $at);

        return (($year - 2000) * 12 * 31 + ($month - 1) * 31 + ($day - 1)) * 86400
            + (int) date('G', $at) * 3600
            + (int) date('i', $at) * 60
            + (int) date('s', $at);
    }

    /**
     * The reply to a terminal's handshake.
     *
     * CRLF-delimited key=value lines, which is what the firmware parses. The
     * stamps are the high-water marks the device asks about; '9999' means "send
     * everything you have", which is what we want on every handshake — the
     * ingest side deduplicates, so re-sent punches cost nothing and a missed
     * batch would cost a day of timesheets.
     */
    public static function handshake(string $serial, int $timezoneOffsetHours): string
    {
        return implode("\r\n", [
            'GET OPTION FROM: '.$serial,
            'Stamp=9999',
            'OpStamp=9999',
            // How long to wait after an error, and between polls. Both in
            // seconds, and both the firmware's own names.
            'ErrorDelay=30',
            'Delay=10',
            'TransTimes=00:00;14:05',
            'TransInterval=1',
            'TransFlag=1111000000',
            'Realtime=1',
            'TimeZone='.$timezoneOffsetHours,
            'Encrypt=0',
        ])."\r\n";
    }

    /**
     * The reply to a command poll.
     *
     * @param  list<array<string, mixed>>  $commands
     */
    public static function commands(array $commands): string
    {
        if ($commands === []) {
            return 'OK';
        }

        $lines = [];

        foreach ($commands as $command) {
            $lines[] = 'C:'.Value::string($command['id'] ?? null).':'.Value::string($command['payload'] ?? null);
        }

        return implode("\r\n", $lines)."\r\n";
    }

    /**
     * One punch from an ATTLOG upload, or null when the line is not one.
     *
     * @return array{pin: string, punched_at: string, status: int|null, verify: int|null, work_code: string|null, raw: string}|null
     */
    public static function parsePunch(string $line): ?array
    {
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
        $punchedAt = self::parseTimestamp(trim($parts[1]));

        if ($pin === '' || $punchedAt === null) {
            return null;
        }

        return [
            'pin' => $pin,
            'punched_at' => $punchedAt,
            'status' => self::optionalInt($parts[2] ?? null),
            'verify' => self::optionalInt($parts[3] ?? null),
            'work_code' => self::optionalString($parts[4] ?? null, 16),
            'raw' => mb_substr($line, 0, 255),
        ];
    }

    /**
     * One line of an OPERLOG upload.
     *
     * Only USER lines carry anything we keep. FP, FACE, BIOPHOTO, USERPIC and
     * BIODATA are megabytes of base64 belonging to the device — matching
     * happens on the terminal, so storing them would be retaining an
     * irrevocable biometric for no purpose.
     *
     * @return array{kind: string, pin?: string, name?: string|null, card?: string|null, privilege?: int|null}|null
     */
    public static function parseOperation(string $line): ?array
    {
        $line = trim($line, "\r\n");

        if ($line === '') {
            return null;
        }

        if (stripos($line, 'USER ') === 0) {
            $fields = self::parseFields(substr($line, 5));
            $pin = trim(Value::string($fields['PIN'] ?? $fields['pin'] ?? null));

            if ($pin === '') {
                return null;
            }

            return [
                'kind' => 'user',
                'pin' => $pin,
                'name' => self::cleanName($fields['Name'] ?? $fields['name'] ?? null),
                'card' => self::optionalString($fields['Card'] ?? $fields['card'] ?? null, 64),
                'privilege' => self::optionalInt($fields['Pri'] ?? null),
            ];
        }

        foreach (['FP ', 'FACE ', 'BIOPHOTO ', 'USERPIC ', 'BIODATA '] as $prefix) {
            if (stripos($line, $prefix) === 0) {
                return ['kind' => 'biometric'];
            }
        }

        return ['kind' => 'other'];
    }

    /**
     * Tab-separated key=value pairs, which is how the firmware sends a record.
     *
     * @return array<string, string>
     */
    public static function parseFields(string $payload): array
    {
        $fields = [];

        foreach (preg_split('/\t+/', $payload) ?: [] as $chunk) {
            $chunk = trim($chunk);

            if ($chunk === '' || ! str_contains($chunk, '=')) {
                continue;
            }

            [$key, $value] = explode('=', $chunk, 2);
            $fields[trim($key)] = trim($value);
        }

        return $fields;
    }

    /**
     * The device's own wall clock, normalised — never converted to any zone.
     *
     * Whatever the terminal thinks the time is *is* the punch time; the
     * company's per-device clock offset corrects a misconfigured one, and that
     * is applied later so the raw value stays auditable.
     */
    public static function parseTimestamp(string $raw): ?string
    {
        $raw = trim(str_replace('T', ' ', $raw));

        if ($raw === '') {
            return null;
        }

        foreach (['Y-m-d H:i:s', 'Y-m-d H:i', 'Y/m/d H:i:s', 'Y/m/d H:i'] as $format) {
            $parsed = DateTimeImmutable::createFromFormat('!'.$format, $raw);

            if ($parsed !== false) {
                return $parsed->format('Y-m-d H:i:s');
            }
        }

        return null;
    }

    private static function cleanName(mixed $raw): ?string
    {
        // Terminals pad short names with NULs and often store mojibake for
        // non-ASCII; keep what is printable and let HR fix the rest.
        $value = trim(str_replace("\0", '', Value::string($raw)));

        return $value === '' ? null : mb_substr($value, 0, 100);
    }

    private static function optionalInt(mixed $raw): ?int
    {
        $value = trim(Value::string($raw));

        return $value === '' ? null : (int) $value;
    }

    private static function optionalString(mixed $raw, int $limit): ?string
    {
        $value = trim(str_replace("\0", '', Value::string($raw)));

        return $value === '' ? null : mb_substr($value, 0, $limit);
    }
}
