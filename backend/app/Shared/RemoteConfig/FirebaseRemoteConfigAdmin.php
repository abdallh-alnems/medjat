<?php

declare(strict_types=1);

namespace App\Shared\RemoteConfig;

use App\Exceptions\ApiFailure;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\RemoteConfig;
use Kreait\Firebase\RemoteConfig\Parameter;
use Kreait\Firebase\RemoteConfig\ParameterValue;
use Kreait\Firebase\RemoteConfig\Template;
use Throwable;

/**
 * The Firebase-backed operator view of the gate.
 *
 * Uncached and fail-loud, unlike the read gate: a panel that quietly reports
 * success on a publish that failed is worse than one that reports an outage,
 * because the operator walks away believing maintenance is on.
 */
final class FirebaseRemoteConfigAdmin implements RemoteConfigAdmin
{
    /**
     * @var array<string, array{name: string, min_version: non-empty-string, maintenance: non-empty-string}>
     */
    private const APPS = [
        'medjat_app' => [
            'name' => 'Employee App',
            'min_version' => 'medjat_app_min_version',
            'maintenance' => 'medjat_app_maintenance_enabled',
        ],
        'medjat_central' => [
            'name' => 'HR Management App',
            'min_version' => 'medjat_central_min_version',
            'maintenance' => 'medjat_central_maintenance_enabled',
        ],
        // The kiosk belongs here even though raising its minimum is the most
        // dangerous button on the screen: a store app can send somebody to a
        // store, but a directly-installed tablet has nowhere to be sent, so
        // somebody must physically visit each branch.
        'medjat_kiosk' => [
            'name' => 'Branch Kiosk',
            'min_version' => 'medjat_kiosk_min_version',
            'maintenance' => 'medjat_kiosk_maintenance_enabled',
        ],
    ];

    public function __construct(private readonly RemoteConfig $remoteConfig) {}

    /**
     * @return list<string>
     */
    public static function apps(): array
    {
        return array_keys(self::APPS);
    }

    /**
     * @return list<array{key: string, name: string, min_version: string, maintenance: bool, supports_maintenance: bool}>
     */
    public function all(): array
    {
        $template = $this->template();
        $apps = [];

        foreach (self::APPS as $key => $config) {
            $apps[] = [
                'key' => $key,
                'name' => $config['name'],
                'min_version' => self::read($template, $config['min_version']) ?? '0.0.0',
                'maintenance' => self::truthy(self::read($template, $config['maintenance'])),
                'supports_maintenance' => true,
            ];
        }

        return $apps;
    }

    /**
     * @return array{app: string, min_version: string, previous_min_version: string}
     */
    public function setMinVersion(string $app, string $version): array
    {
        $config = self::config($app);
        $template = $this->template();

        $previous = self::read($template, $config['min_version']) ?? '0.0.0';

        $this->publish($template, $config['min_version'], $version);

        return ['app' => $app, 'min_version' => $version, 'previous_min_version' => $previous];
    }

    /**
     * @return array{app: string, maintenance: bool, previous_maintenance: bool}
     */
    public function setMaintenance(string $app, bool $enabled): array
    {
        $config = self::config($app);
        $template = $this->template();

        $previous = self::truthy(self::read($template, $config['maintenance']));

        $this->publish($template, $config['maintenance'], $enabled ? 'true' : 'false');

        return ['app' => $app, 'maintenance' => $enabled, 'previous_maintenance' => $previous];
    }

    /**
     * @return array{name: string, min_version: non-empty-string, maintenance: non-empty-string}
     */
    private static function config(string $app): array
    {
        $config = self::APPS[$app] ?? null;

        if ($config === null) {
            throw new ApiFailure('Invalid app', 422, 'invalid_app');
        }

        return $config;
    }

    private function template(): Template
    {
        try {
            return $this->remoteConfig->get();
        } catch (Throwable $e) {
            Log::error('Remote Config fetch failed', ['exception' => $e]);

            throw new ApiFailure('Failed to fetch Remote Config', 503, 'remote_config_unavailable');
        }
    }

    /**
     * @param  non-empty-string  $key
     */
    private function publish(Template $template, string $key, string $value): void
    {
        try {
            $this->remoteConfig->publish(
                $template->withParameter(Parameter::named($key)->withDefaultValue($value))
            );
        } catch (Throwable $e) {
            Log::error('Remote Config publish failed', ['key' => $key, 'exception' => $e]);

            throw new ApiFailure('Failed to update Remote Config', 503, 'remote_config_unavailable');
        }
    }

    private static function read(Template $template, string $key): ?string
    {
        $parameters = $template->parameters();

        if (! isset($parameters[$key])) {
            return null;
        }

        $default = $parameters[$key]->defaultValue();

        if (! $default instanceof ParameterValue) {
            return null;
        }

        // Through toArray(): ParameterValue exposes no accessor, and a
        // parameter that is an in-app default or a rollout carries no plain
        // value at all.
        $value = $default->toArray()['value'] ?? null;

        return is_string($value) ? $value : null;
    }

    /** Remote Config stores booleans as strings, and not always the same one. */
    private static function truthy(?string $value): bool
    {
        return $value === 'true' || $value === '1';
    }
}
