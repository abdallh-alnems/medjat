<?php

declare(strict_types=1);

namespace App\Modules\Terminal\Http\Controllers;

use App\Modules\Devices\Domain\AttendanceDevice;
use App\Modules\Devices\Domain\DeviceCommands;
use App\Modules\Devices\Domain\PunchIngestor;
use App\Modules\Devices\Domain\ZktecoProtocol;
use App\Support\Value;
use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Port of api/device/iclock.php.
 *
 * The ZKTeco ADMS endpoint — the only door in this codebase not opened by a
 * signed-in human.
 *
 * A terminal cannot send a bearer token, a Firebase token, or Basic
 * credentials; the firmware has nowhere to put them. What it does send on every
 * request is its serial number, and a serial no company has claimed can do
 * nothing here but leave a "device seen" mark. That is the whole authorisation
 * model, and it is why claiming a serial is one-way and exclusive.
 *
 * Two rules govern every path below:
 *
 * Always answer 200 with plain text. A device that receives an error re-sends
 * the same batch in a loop until it gets a 200, recording nothing new in the
 * meantime — so an error status turns a small problem into a branch with no
 * attendance.
 *
 * Never let an exception escape. By the time anything interesting can fail, the
 * punches are already stored.
 */
final class IclockController
{
    /** When a company's zone cannot be read: Cairo, where most of them are. */
    private const FALLBACK_OFFSET_HOURS = 2;

    public function __construct(private readonly PunchIngestor $ingestor) {}

    public function __invoke(Request $request): Response
    {
        $serial = AttendanceDevice::normaliseSerial(
            $request->query('SN') ?? $request->query('sn')
        );

        // No serial is not a device we can help. Answer OK so it stops
        // retrying rather than spinning.
        if ($serial === '') {
            return self::reply('OK');
        }

        try {
            $device = AttendanceDevice::recordContact($serial, $request->ip());
        } catch (Throwable $e) {
            Log::warning('Device contact failed', ['serial' => $serial, 'exception' => $e]);

            return self::reply('OK');
        }

        // Registered but switched off in the app. Stay polite: the terminal
        // keeps its own log and delivers it when re-enabled.
        if (Value::string($device['status'] ?? null) === 'disabled') {
            return self::reply('OK');
        }

        try {
            return self::reply($this->dispatch($request, $device, $serial));
        } catch (Throwable $e) {
            Log::error('Device endpoint failed', ['serial' => $serial, 'exception' => $e]);

            // Still 200: the punches were stored before anything here could
            // fail, and an error would only make the terminal resend them.
            return self::reply('OK');
        }
    }

    /**
     * @param  array<string, mixed>  $device
     */
    private function dispatch(Request $request, array $device, string $serial): string
    {
        return match (self::action($request)) {
            'cdata' => $this->cdata($request, $device, $serial),
            'getrequest' => $this->commands($device),
            'devicecmd' => $this->commandResult($request, $device),
            // ping, fdata, edata, querydata and anything else: acknowledged and
            // dropped. Biometric payloads belong to the terminal, which does
            // its own matching.
            default => 'OK',
        };
    }

    /**
     * The handshake, and every upload the device pushes.
     *
     * @param  array<string, mixed>  $device
     */
    private function cdata(Request $request, array $device, string $serial): string
    {
        $deviceId = Value::int($device['id'] ?? null);

        if ($request->isMethod('GET')) {
            AttendanceDevice::updateInfo($deviceId, [
                'model' => $request->query('DeviceType') ?? $request->query('model'),
                'firmware' => $request->query('pushver'),
            ]);

            return ZktecoProtocol::handshake($serial, self::offsetHours($device));
        }

        $body = $request->getContent();

        return match (strtoupper(Value::string($request->query('table')))) {
            'ATTLOG' => 'OK: '.$this->ingestor->ingestPunches($device, $body),
            'OPERLOG' => $this->operlog($device, $body),
            // OPTIONS carries the device's self-description on some firmware,
            // and an empty table is the same thing on others.
            'OPTIONS', '' => $this->options($deviceId, $body),
            // ATTPHOTO and friends: acknowledged, not stored.
            default => 'OK',
        };
    }

    /**
     * @param  array<string, mixed>  $device
     */
    private function operlog(array $device, string $body): string
    {
        $this->ingestor->ingestOperations($device, $body);

        return 'OK';
    }

    private function options(int $deviceId, string $body): string
    {
        // Some firmware separates these with newlines rather than tabs.
        $fields = ZktecoProtocol::parseFields(str_replace(["\r\n", "\n"], "\t", $body));

        AttendanceDevice::updateInfo($deviceId, [
            'model' => $fields['DeviceName'] ?? $fields['~DeviceName'] ?? null,
            'firmware' => $fields['FWVersion'] ?? $fields['~ZKFPVersion'] ?? null,
            'user_count' => isset($fields['UserCount']) ? (int) $fields['UserCount'] : null,
        ]);

        return 'OK';
    }

    /**
     * @param  array<string, mixed>  $device
     */
    private function commands(array $device): string
    {
        // An unclaimed device belongs to no company, so there is nothing
        // anybody could have queued for it.
        if (Value::nullableInt($device['tenant_id'] ?? null) === null) {
            return 'OK';
        }

        $deviceId = Value::int($device['id'] ?? null);

        DeviceCommands::pruneStale($deviceId);

        return ZktecoProtocol::commands(DeviceCommands::claim($deviceId));
    }

    /**
     * @param  array<string, mixed>  $device
     */
    private function commandResult(Request $request, array $device): string
    {
        // The body is tab or newline separated key=value, which parse_str reads
        // once the separators are normalised to ampersands.
        $fields = [];
        parse_str(str_replace(["\r\n", "\n", "\t"], '&', $request->getContent()), $fields);

        $commandId = Value::int($fields['ID'] ?? null);

        if ($commandId > 0) {
            DeviceCommands::complete(
                $commandId,
                Value::int($device['id'] ?? null),
                Value::nullableString($fields['Return'] ?? null),
            );
        }

        return 'OK';
    }

    /**
     * Which verb the device is speaking.
     *
     * Normal routing gives /iclock/<action>; the query parameter is the
     * fallback for calling the endpoint directly, which is how it is tested.
     */
    private static function action(Request $request): string
    {
        // No leading slash required: Request::path() does not carry one, and
        // the pattern also has to match a deployment that nests the route.
        if (preg_match('#(?:^|/)iclock/([a-z]+)#', strtolower($request->path()), $matches) === 1) {
            return $matches[1];
        }

        $action = strtolower(Value::string($request->query('action')));

        return preg_replace('/[^a-z]/', '', $action) ?: 'cdata';
    }

    /**
     * The company's current UTC offset in whole hours, which is all the
     * protocol can express.
     *
     * @param  array<string, mixed>  $device
     */
    private static function offsetHours(array $device): int
    {
        $tenantId = Value::nullableInt($device['tenant_id'] ?? null);

        $zone = $tenantId === null
            ? null
            : Value::nullableString(DB::table('tenants')->where('id', $tenantId)->value('timezone'));

        try {
            $offset = (new DateTimeZone($zone ?? 'Africa/Cairo'))
                ->getOffset(new DateTimeImmutable('now', new DateTimeZone('UTC')));

            return (int) round($offset / 3600);
        } catch (Throwable) {
            return self::FALLBACK_OFFSET_HOURS;
        }
    }

    private static function reply(string $body): Response
    {
        return new Response($body, 200, [
            'Content-Type' => 'text/plain; charset=utf-8',
            'Cache-Control' => 'no-store',
        ]);
    }
}
