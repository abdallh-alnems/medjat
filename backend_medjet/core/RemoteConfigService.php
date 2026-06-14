<?php

require_once __DIR__ . '/../config/firebase.php';

use Kreait\Firebase\RemoteConfig as RcContract;
use Kreait\Firebase\RemoteConfig\Parameter;
use Kreait\Firebase\RemoteConfig\Template;

final class RemoteConfigService {
    private const APPS = [
        'medjat_app' => [
            'name' => 'Employee App',
            'min_version_key' => 'medjat_app_min_version',
            'maintenance_key' => 'medjat_app_maintenance_enabled',
            'supports_maintenance' => true,
        ],
        'medjat_central' => [
            'name' => 'HR Management App',
            'min_version_key' => 'medjat_central_min_version',
            'maintenance_key' => 'medjat_central_maintenance_enabled',
            'supports_maintenance' => true,
        ],
    ];

    private static ?RcContract $rc = null;

    private static function getRemoteConfig(): RcContract {
        if (self::$rc === null) {
            $credentialsPath = getenv('FIREBASE_CREDENTIALS_PATH')
                ?: __DIR__ . '/firebase_credentials.json';

            $factory = (new \Kreait\Firebase\Factory)->withServiceAccount($credentialsPath);
            self::$rc = $factory->createRemoteConfig();
        }
        return self::$rc;
    }

    public static function getAll(): array {
        try {
            $template = self::getRemoteConfig()->get();
        } catch (Exception $e) {
            error_log('Remote Config fetch error: ' . $e->getMessage());
            Response::error('Failed to fetch Remote Config', 503);
        }

        $apps = [];
        foreach (self::APPS as $key => $config) {
            $minVersion = self::getParameterValue($template, $config['min_version_key']) ?? '0.0.0';
            $rawMaint = $config['supports_maintenance']
                ? self::getParameterValue($template, $config['maintenance_key'])
                : null;
            $maintenance = ($rawMaint === 'true' || $rawMaint === '1');

            $apps[] = [
                'key' => $key,
                'name' => $config['name'],
                'min_version' => $minVersion,
                'maintenance' => $maintenance,
                'supports_maintenance' => $config['supports_maintenance'],
            ];
        }

        return ['apps' => $apps];
    }

    public static function setVersion(string $app, string $version): array {
        $config = self::APPS[$app] ?? null;
        if (!$config) {
            Response::fail('Invalid app', 422);
        }

        if (!preg_match('/^\d+(\.\d+){0,3}$/', $version)) {
            Response::fail('Invalid version format', 422);
        }

        try {
            $template = self::getRemoteConfig()->get();
            $previousValue = self::getParameterValue($template, $config['min_version_key']) ?? '0.0.0';

            $template = self::updateParameter($template, $config['min_version_key'], $version);
            self::getRemoteConfig()->publish($template);
        } catch (Exception $e) {
            error_log('Remote Config set version error: ' . $e->getMessage());
            Response::error('Failed to update Remote Config', 503);
        }

        return [
            'app' => $app,
            'min_version' => $version,
            'previous_min_version' => $previousValue,
        ];
    }

    public static function setMaintenance(string $app, bool $enabled): array {
        $config = self::APPS[$app] ?? null;
        if (!$config) {
            Response::fail('Invalid app', 422);
        }
        if (!$config['supports_maintenance']) {
            Response::fail('Maintenance control not available for this app', 422);
        }

        try {
            $template = self::getRemoteConfig()->get();
            $rawPrev = self::getParameterValue($template, $config['maintenance_key']);
            $previousValue = ($rawPrev === 'true' || $rawPrev === '1');

            $template = self::updateParameter($template, $config['maintenance_key'], $enabled ? 'true' : 'false');
            self::getRemoteConfig()->publish($template);
        } catch (Exception $e) {
            error_log('Remote Config set maintenance error: ' . $e->getMessage());
            Response::error('Failed to update Remote Config', 503);
        }

        return [
            'app' => $app,
            'maintenance' => $enabled,
            'previous_maintenance' => $previousValue,
        ];
    }

    private static function getParameterValue(Template $template, string $key): ?string {
        $parameters = $template->parameters();
        if (!isset($parameters[$key])) {
            return null;
        }
        $defaultValue = $parameters[$key]->defaultValue();
        if ($defaultValue === null) {
            return null;
        }
        $arr = $defaultValue->toArray();
        return $arr['value'] ?? null;
    }

    private static function updateParameter(Template $template, string $key, string $value): Template {
        $parameters = $template->parameters();
        if (isset($parameters[$key])) {
            $updated = $parameters[$key]->withDefaultValue($value);
        } else {
            $updated = Parameter::named($key, $value);
        }
        return $template->withParameter($updated);
    }
}
