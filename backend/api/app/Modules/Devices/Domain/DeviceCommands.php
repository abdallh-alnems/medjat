<?php

declare(strict_types=1);

namespace App\Modules\Devices\Domain;

use App\Support\Value;
use Illuminate\Support\Facades\DB;

/**
 * Work queued for a terminal.
 *
 * A device is unreachable by design — it dials out, we never dial in — so
 * anything we want it to do waits here until it next polls. That also means a
 * command can outlive its usefulness, which is what the pruning is for.
 */
final class DeviceCommands
{
    /** Per poll. A terminal that has been offline should not get a flood. */
    private const BATCH = 5;

    /** After this, a command is stale enough that doing it would surprise. */
    private const STALE_HOURS = 24;

    /**
     * Hands the device its next commands and marks them sent.
     *
     * @return list<array<string, mixed>>
     */
    public static function claim(int $deviceId): array
    {
        $rows = DB::table('device_commands')
            ->where('device_id', $deviceId)->where('state', 'queued')
            ->orderBy('id')->limit(self::BATCH)
            ->get(['id', 'kind', 'payload'])
            ->all();

        if ($rows === []) {
            return [];
        }

        $commands = array_values(array_map(
            static function (mixed $row): array {
                /** @var array<string, mixed> $command */
                $command = (array) $row;

                return $command;
            },
            $rows,
        ));

        DB::table('device_commands')
            ->whereIn('id', array_map(static fn (array $c): int => Value::int($c['id'] ?? null), $commands))
            ->update(['state' => 'sent', 'sent_at' => DB::raw('NOW()')]);

        return $commands;
    }

    /**
     * Records what the device made of a command.
     *
     * Return code 0 is success in the ADMS protocol; anything else is the
     * terminal saying it could not do it. An absent code is treated as success
     * because some firmware acknowledges without one.
     */
    public static function complete(int $commandId, int $deviceId, ?string $returnCode): void
    {
        $ok = $returnCode === null || $returnCode === '' || (int) $returnCode === 0;

        DB::table('device_commands')
            ->where('id', $commandId)->where('device_id', $deviceId)
            ->update([
                'state' => $ok ? 'done' : 'failed',
                'result_code' => $returnCode,
                'completed_at' => DB::raw('NOW()'),
            ]);
    }

    /**
     * Fails commands old enough that executing them would be a surprise.
     *
     * A tablet that comes back after a week should not suddenly apply what
     * somebody queued before the problem was solved another way.
     */
    public static function pruneStale(int $deviceId): void
    {
        DB::table('device_commands')
            ->where('device_id', $deviceId)
            ->whereIn('state', ['queued', 'sent'])
            ->whereRaw('created_at < DATE_SUB(NOW(), INTERVAL ? HOUR)', [self::STALE_HOURS])
            ->update(['state' => 'failed', 'result_code' => 'expired']);
    }
}
