<?php

declare(strict_types=1);

namespace App\Shared\RemoteConfig;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\RemoteConfig;
use Kreait\Firebase\RemoteConfig\ParameterValue;
use Throwable;

/**
 * Reads the gate from Firebase Remote Config.
 *
 * Cached for five minutes, and — more importantly — fails open twice over. A
 * fetch that throws falls back to the last known-good answer kept for a day;
 * having never seen one at all, it returns an open gate. A Firebase outage must
 * not take every tablet in every company out of service, and the cost of the
 * opposite mistake is only that an outdated build runs a while longer.
 */
final class FirebaseRemoteConfigGate implements RemoteConfigGate
{
    private const TTL_SECONDS = 300;

    private const LAST_GOOD_TTL_SECONDS = 86400;

    /**
     * The apps whose builds this server gates. A key that is not here has no
     * gate rather than a closed one.
     *
     * @var array<string, array{min_version: string, maintenance: string}>
     */
    private const APPS = [
        'medjat_app' => [
            'min_version' => 'medjat_app_min_version',
            'maintenance' => 'medjat_app_maintenance_enabled',
        ],
        'medjat_central' => [
            'min_version' => 'medjat_central_min_version',
            'maintenance' => 'medjat_central_maintenance_enabled',
        ],
        // Raising the kiosk minimum takes branches offline: the store apps can
        // send a user to a store, but a directly-installed kiosk has nowhere to
        // be sent, so somebody must physically visit each tablet.
        'medjat_kiosk' => [
            'min_version' => 'medjat_kiosk_min_version',
            'maintenance' => 'medjat_kiosk_maintenance_enabled',
        ],
    ];

    public function __construct(private readonly RemoteConfig $remoteConfig) {}

    public function forApp(string $app): AppGate
    {
        $keys = self::APPS[$app] ?? null;

        if ($keys === null) {
            return AppGate::open();
        }

        $cacheKey = 'rc_gate_'.$app;
        $cached = Cache::get($cacheKey);

        if (is_array($cached)) {
            return new AppGate(
                is_string($cached['min_version'] ?? null) ? $cached['min_version'] : '0.0.0',
                (bool) ($cached['maintenance'] ?? false),
                false,
            );
        }

        try {
            $template = $this->remoteConfig->get();

            $minVersion = $this->parameterValue($template, $keys['min_version']) ?? '0.0.0';
            $maintenance = in_array($this->parameterValue($template, $keys['maintenance']), ['true', '1'], true);

            $gate = ['min_version' => $minVersion, 'maintenance' => $maintenance];

            Cache::put($cacheKey, $gate, self::TTL_SECONDS);
            // Kept far longer than the live entry, purely so an outage reuses
            // the last known-good answer instead of an open gate.
            Cache::put($cacheKey.'_last_good', $gate, self::LAST_GOOD_TTL_SECONDS);

            return new AppGate($minVersion, $maintenance, false);
        } catch (Throwable $e) {
            Log::warning('Remote Config gate fetch failed', ['app' => $app, 'exception' => $e]);

            $lastGood = Cache::get($cacheKey.'_last_good');

            if (is_array($lastGood)) {
                return new AppGate(
                    is_string($lastGood['min_version'] ?? null) ? $lastGood['min_version'] : '0.0.0',
                    (bool) ($lastGood['maintenance'] ?? false),
                    true,
                );
            }

            return AppGate::open(true);
        }
    }

    private function parameterValue(mixed $template, string $key): ?string
    {
        if (! is_object($template) || ! method_exists($template, 'parameters')) {
            return null;
        }

        /** @var array<string, mixed> $parameters */
        $parameters = $template->parameters();
        $parameter = $parameters[$key] ?? null;

        if (! is_object($parameter) || ! method_exists($parameter, 'defaultValue')) {
            return null;
        }

        $default = $parameter->defaultValue();

        if (! $default instanceof ParameterValue) {
            return null;
        }

        // Through toArray(), because ParameterValue exposes no accessor. A
        // parameter can also be an in-app default, a personalisation or a
        // rollout, none of which carry a plain value — those come back with no
        // 'value' key, and an absent gate is an open one.
        $value = $default->toArray()['value'] ?? null;

        return is_string($value) ? $value : null;
    }
}
