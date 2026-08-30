<?php

declare(strict_types=1);

namespace App\Domain\Devices;

use App\Support\Value;

/**
 * The dialect ZKTeco terminals speak.
 *
 * Only the parts the management surface needs: how a verify code maps to a
 * recognition method, and what a queued command looks like on the wire. The
 * device-facing endpoint that speaks the full protocol is separate.
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
}
