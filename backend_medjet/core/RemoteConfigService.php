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
        // The branch kiosk carries no Firebase SDK: it reports its version on
        // every heartbeat and the server answers 426/503 by reading these
        // parameters itself. That keeps a google-services.json and an FCM
        // dependency off a wall-mounted tablet for no loss of control.
        //
        // One caveat when raising the minimum. The store apps can send a user
        // to a store; a directly-installed kiosk has nowhere to be sent, so
        // raising this takes those branches OFFLINE until somebody installs the
        // new build on each tablet. Check app/kiosk/list.php for
        // `below_min_version` before changing it.
        'medjat_kiosk' => [
            'name' => 'Branch Kiosk',
            'min_version_key' => 'medjat_kiosk_min_version',
            'maintenance_key' => 'medjat_kiosk_maintenance_enabled',
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

    /**
     * The version gate for one app, cached and **fail-open**.
     *
     * `getAll()` is wrong for a per-request gate in two ways. It calls the
     * Firebase API every time — acceptable for an admin screen opened
     * occasionally, not for a heartbeat that fires from every kiosk in every
     * branch — and on failure it answers `Response::error(503)`, which would end
     * the request.
     *
     * Failing open matters more than it sounds. If Firebase is briefly
     * unreachable and this failed closed, **every kiosk in every company would
     * stop recording attendance at once** because of an outage in a service that
     * has nothing to do with attendance. A stale-but-cached minimum version is
     * strictly better than that, and the worst case of failing open is that an
     * outdated tablet keeps working for a few more minutes.
     *
     * @return array{min_version: string, maintenance: bool, stale: bool}
     */
    public static function gateFor(string $app, int $ttlSeconds = 300): array {
        $config = self::APPS[$app] ?? null;
        if (!$config) {
            return ['min_version' => '0.0.0', 'maintenance' => false, 'stale' => false];
        }

        $cacheKey = 'rc_gate_' . $app;

        $cached = Cache::getInstance()->get($cacheKey);
        if ($cached !== null) {
            return $cached + ['stale' => false];
        }

        try {
            $template = self::getRemoteConfig()->get();

            $rawMaint = $config['supports_maintenance']
                ? self::getParameterValue($template, $config['maintenance_key'])
                : null;

            $gate = [
                'min_version' => self::getParameterValue($template, $config['min_version_key']) ?? '0.0.0',
                'maintenance' => ($rawMaint === 'true' || $rawMaint === '1'),
            ];

            Cache::getInstance()->set($cacheKey, $gate, $ttlSeconds);
            // Kept far longer than the live entry purely as a fallback for the
            // catch below, so an outage reuses the last known-good answer
            // instead of an open gate.
            Cache::getInstance()->set($cacheKey . '_last_good', $gate, 86400);

            return $gate + ['stale' => false];
        } catch (Exception $e) {
            error_log('Remote Config gate fetch failed for ' . $app . ': ' . $e->getMessage());

            $lastGood = Cache::getInstance()->get($cacheKey . '_last_good');
            if (is_array($lastGood)) {
                return $lastGood + ['stale' => true];
            }

            // Never seen a value at all: let the tablets work.
            return ['min_version' => '0.0.0', 'maintenance' => false, 'stale' => true];
        }
    }

    /**
     * Dotted version comparison, tolerant of differing segment counts.
     * "1.2" is not below "1.2.0".
     */
    public static function isBelow(string $version, string $minimum): bool {
        return version_compare($version ?: '0.0.0', $minimum ?: '0.0.0', '<');
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
